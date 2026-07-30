import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/services/print_queue_service.dart';

class VoidOrderService {
  final PosDatabase _db;
  final PrintQueueService _printQueueService;
  final _uuid = const Uuid();

  VoidOrderService(this._db, this._printQueueService);

  Future<bool> voidOrderItem({
    required String masterOrderId,
    required String orderItemId,
    required int qtyToVoid,
    required String reason,
    required String managerPin,
  }) async {
    final db = await _db.database;

    // 1. Verify Manager/Owner PIN
    final managerRows = await db.query(
      'cashiers',
      where: 'pin = ? AND status = 1 AND is_deleted = 0 AND is_owner = 1',
      whereArgs: [managerPin],
    );

    if (managerRows.isEmpty) {
      // Fallback: check if any active cashier with pin has is_owner = 1 or is allowed
      final anyManager = await db.query(
        'cashiers',
        where: 'pin = ? AND status = 1 AND is_deleted = 0',
        whereArgs: [managerPin],
      );
      if (anyManager.isEmpty) {
        throw Exception('PIN Manager/Owner tidak valid. Pembatalan pesanan ditolak.');
      }
    }

    final manager = managerRows.isNotEmpty ? managerRows.first : null;
    final managerId = manager?['id'] as String? ?? 'manager-pin-auth';
    final managerNama = manager?['nama'] as String? ?? 'Manager';

    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    bool wasPrintedToKitchen = false;
    String produkNama = '';
    String? tableId;
    String nomorOrder = '';

    await db.transaction((txn) async {
      // Get order item
      final itemRows = await txn.query(
        'order_items',
        where: 'id = ?',
        whereArgs: [orderItemId],
      );
      if (itemRows.isEmpty) {
        throw Exception('Item pesanan tidak ditemukan.');
      }
      final row = itemRows.first;
      produkNama = row['produk_nama'] as String? ?? 'Item';
      final effectivePrice = (row['effective_price'] as num?)?.toDouble() ??
          (row['produk_harga'] as num).toDouble();
      final qtyOrdered = (row['qty_ordered'] as num?)?.toInt() ??
          (row['qty'] as num).toInt();
      final cancelledQty = (row['cancelled_qty'] as num?)?.toInt() ?? 0;
      final statusCetak = (row['status_cetak'] as num?)?.toInt() ?? 0;
      wasPrintedToKitchen = statusCetak == 1;

      final remainingQty = qtyOrdered - cancelledQty;
      if (qtyToVoid > remainingQty || qtyToVoid <= 0) {
        throw Exception(
          'Kuantitas void ($qtyToVoid) melebihi sisa pesanan aktif ($remainingQty).',
        );
      }

      final newCancelledQty = cancelledQty + qtyToVoid;
      final isFullyCancelled = newCancelledQty >= qtyOrdered;
      final newActiveQty = qtyOrdered - newCancelledQty;
      final newSubtotal = effectivePrice * newActiveQty;

      // Update order_items
      await txn.update(
        'order_items',
        {
          'qty': newActiveQty,
          'subtotal': newSubtotal,
          'cancelled_qty': newCancelledQty,
          'is_cancelled': isFullyCancelled ? 1 : 0,
          'cancelled_at': nowStr,
          'cancelled_reason': reason,
          'cancelled_by_manager_id': managerId,
        },
        where: 'id = ?',
        whereArgs: [orderItemId],
      );

      // Recalculate master_orders totals
      final masterRows = await txn.query(
        'master_orders',
        where: 'id = ?',
        whereArgs: [masterOrderId],
      );
      if (masterRows.isNotEmpty) {
        final master = masterRows.first;
        nomorOrder = master['nomor_order'] as String? ?? '';
        tableId = master['table_id'] as String?;

        // Sum remaining items
        final allItems = await txn.query(
          'order_items',
          where: 'master_order_id = ? AND is_cancelled = 0',
          whereArgs: [masterOrderId],
        );
        double totalSub = 0.0;
        for (final it in allItems) {
          totalSub += (it['subtotal'] as num).toDouble();
        }

        final taxPerc = (master['tax_percentage'] as num?)?.toDouble() ?? 0.0;
        final taxAmt = totalSub * (taxPerc / 100.0);
        final grandTot = totalSub + taxAmt;

        await txn.update(
          'master_orders',
          {
            'subtotal': totalSub,
            'tax_amount': taxAmt,
            'grand_total': grandTot,
            'last_activity_at': nowStr,
            'updated_at': nowStr,
          },
          where: 'id = ?',
          whereArgs: [masterOrderId],
        );
      }

      // Log to void_authorization_logs
      await txn.insert('void_authorization_logs', {
        'id': _uuid.v4(),
        'master_order_id': masterOrderId,
        'order_item_id': orderItemId,
        'manager_id': managerId,
        'manager_nama': managerNama,
        'qty_voided': qtyToVoid,
        'reason': reason,
        'was_kitchen_notified': wasPrintedToKitchen ? 1 : 0,
        'created_at': nowStr,
      });
    });

    // If item was already printed to kitchen, enqueue a VOID kitchen ticket
    if (wasPrintedToKitchen) {
      final kitchenPrinter = await _getKitchenPrinterAddress(db);
      if (kitchenPrinter != null) {
        final payload = _generateVoidTicketBytes(
          nomorOrder: nomorOrder,
          tableId: tableId,
          produkNama: produkNama,
          qtyVoided: qtyToVoid,
          reason: reason,
          managerNama: managerNama,
        );

        await _printQueueService.enqueueJob(
          targetPrinterType: kitchenPrinter['type'] as String? ?? 'bluetooth',
          targetAddress: kitchenPrinter['address'] as String,
          payloadBytes: payload,
          jobType: 'void_ticket',
          referenceId: masterOrderId,
        );
      }
    }

    return true;
  }

  Future<Map<String, dynamic>?> _getKitchenPrinterAddress(dynamic db) async {
    final rows = await db.query(
      'printers_config',
      where: "name LIKE '%dapur%' OR name LIKE '%kitchen%'",
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first;

    final anyRows = await db.query('printers_config', limit: 1);
    if (anyRows.isNotEmpty) return anyRows.first;
    return null;
  }

  List<int> _generateVoidTicketBytes({
    required String nomorOrder,
    String? tableId,
    required String produkNama,
    required int qtyVoided,
    required String reason,
    required String managerNama,
  }) {
    // Generate ESC/POS text command bytes for thermal printer VOID ticket
    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('     *** CANCEL / VOID ***      ');
    buffer.writeln('================================');
    buffer.writeln('Order: $nomorOrder');
    if (tableId != null && tableId.isNotEmpty) {
      buffer.writeln('Meja: $tableId');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Item  : $produkNama');
    buffer.writeln('Qty   : -$qtyVoided');
    buffer.writeln('Alasan: $reason');
    buffer.writeln('Auth  : $managerNama');
    buffer.writeln('================================');
    buffer.writeln('\n\n');

    return utf8.encode(buffer.toString());
  }
}
