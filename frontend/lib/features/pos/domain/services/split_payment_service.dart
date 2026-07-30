import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';

class SplitPaymentItemRequest {
  final String orderItemId;
  final int qtyToPay;

  const SplitPaymentItemRequest({
    required this.orderItemId,
    required this.qtyToPay,
  });
}

class SplitPaymentService {
  final PosDatabase _db;
  final _uuid = const Uuid();

  SplitPaymentService(this._db);

  Future<String> checkoutSplitItems({
    required String masterOrderId,
    required List<SplitPaymentItemRequest> itemsToPay,
    required String paymentMethodId,
    required String paymentMethodNama,
    required double nominalBayar,
    String? cashierId,
    String? cashierNama,
    String? customerName,
    String? catatan,
  }) async {
    final db = await _db.database;

    if (itemsToPay.isEmpty) {
      throw Exception('Tidak ada item yang dipilih untuk pembayaran split.');
    }

    final transactionId = _uuid.v4();
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final nomorTransaksi = 'TRX-SPLIT-${now.millisecondsSinceEpoch}';

    return await db.transaction((txn) async {
      double subtotal = 0.0;

      // Validate & compute subtotal from order_items
      for (final req in itemsToPay) {
        final itemRows = await txn.query(
          'order_items',
          where: 'id = ?',
          whereArgs: [req.orderItemId],
        );
        if (itemRows.isEmpty) {
          throw Exception('Item pesanan dengan ID ${req.orderItemId} tidak ditemukan.');
        }
        final row = itemRows.first;
        final effectivePrice = (row['effective_price'] as num?)?.toDouble() ??
            (row['produk_harga'] as num).toDouble();
        final qtyOrdered = (row['qty_ordered'] as num?)?.toInt() ??
            (row['qty'] as num).toInt();
        final qtyPaid = (row['qty_paid'] as num?)?.toInt() ?? 0;
        final cancelledQty = (row['cancelled_qty'] as num?)?.toInt() ?? 0;
        final remainingQty = qtyOrdered - qtyPaid - cancelledQty;

        if (req.qtyToPay > remainingQty || req.qtyToPay <= 0) {
          throw Exception(
            'Kuantitas bayar (${req.qtyToPay}) tidak valid untuk item ${row['produk_nama']}. Sisa bayar: $remainingQty.',
          );
        }

        final itemSubtotal = effectivePrice * req.qtyToPay;
        subtotal += itemSubtotal;

        // Update qty_paid in order_items
        await txn.update(
          'order_items',
          {
            'qty_paid': qtyPaid + req.qtyToPay,
          },
          where: 'id = ?',
          whereArgs: [req.orderItemId],
        );

        // Insert into transaction_items
        await txn.insert('transaction_items', {
          'id': _uuid.v4(),
          'transaction_id': transactionId,
          'order_item_id': req.orderItemId,
          'produk_id': row['produk_id'],
          'produk_nama': row['produk_nama'],
          'produk_harga': effectivePrice,
          'qty': req.qtyToPay,
          'subtotal': itemSubtotal,
          'catatan': row['catatan'],
        });
      }

      // Check tax setting
      final taxRows = await txn.query('tax_settings', where: 'id = 1');
      double taxPercentage = 0.0;
      double taxAmount = 0.0;
      if (taxRows.isNotEmpty) {
        final enable = (taxRows.first['enable'] as num?)?.toInt() ?? 0;
        if (enable == 1) {
          taxPercentage = (taxRows.first['percentage'] as num?)?.toDouble() ?? 0.0;
          taxAmount = subtotal * (taxPercentage / 100.0);
        }
      }

      final grandTotal = subtotal + taxAmount;
      final kembalian = nominalBayar > grandTotal ? nominalBayar - grandTotal : 0.0;

      // Insert transaction header
      await txn.insert('transactions', {
        'id': transactionId,
        'nomor_transaksi': nomorTransaksi,
        'master_order_id': masterOrderId,
        'subtotal': subtotal,
        'tax_percentage': taxPercentage,
        'tax_amount': taxAmount,
        'grand_total': grandTotal,
        'payment_method_id': paymentMethodId,
        'payment_method_nama': paymentMethodNama,
        'nominal_bayar': nominalBayar,
        'kembalian': kembalian,
        'catatan': catatan,
        'customer_name': customerName,
        'order_type': 'dine_in_postpaid',
        'status': 'completed',
        'cashier_id': cashierId,
        'cashier_nama': cashierNama,
        'created_at': nowStr,
      });

      // Update master_orders total_paid and payment_status
      final masterRows = await txn.query(
        'master_orders',
        where: 'id = ?',
        whereArgs: [masterOrderId],
      );

      if (masterRows.isNotEmpty) {
        final master = masterRows.first;
        final currentTotalPaid = (master['total_paid'] as num?)?.toDouble() ?? 0.0;
        final masterGrandTotal = (master['grand_total'] as num?)?.toDouble() ?? 0.0;
        final newTotalPaid = currentTotalPaid + grandTotal;

        final isFullyPaid = newTotalPaid >= (masterGrandTotal - 1.0); // 1 rupiah tolerance
        final newPaymentStatus = isFullyPaid ? 'paid' : 'partially_paid';
        final newSessionStatus = isFullyPaid ? 'settled' : 'open';

        await txn.update(
          'master_orders',
          {
            'total_paid': newTotalPaid,
            'payment_status': newPaymentStatus,
            'session_status': newSessionStatus,
            'last_activity_at': nowStr,
            'updated_at': nowStr,
          },
          where: 'id = ?',
          whereArgs: [masterOrderId],
        );

        // If fully paid and table is attached, set table status to available (0) or prepaid (2)
        final tableId = master['table_id'] as String?;
        if (tableId != null && tableId.isNotEmpty) {
          if (isFullyPaid) {
            await txn.update(
              'tables',
              {
                'status': 2, // 2 = Occupied Prepaid / settled waiting to clear
                'updated_at': nowStr,
              },
              where: 'id = ?',
              whereArgs: [tableId],
            );
          }
        }
      }

      return transactionId;
    });
  }
}
