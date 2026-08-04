import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';

class OnlineOrderItemRequest {
  final String produkId;
  final String produkNama;
  final double defaultHarga;
  final int qty;
  final String? catatan;

  const OnlineOrderItemRequest({
    required this.produkId,
    required this.produkNama,
    required this.defaultHarga,
    required this.qty,
    this.catatan,
  });
}

class OnlineFoodOrderService {
  final PosDatabase _db;
  final _uuid = const Uuid();

  OnlineFoodOrderService(this._db);

  Future<double> getEffectiveSkuPrice({
    required String platformId,
    required String produkId,
    required double defaultPrice,
  }) async {
    final db = await _db.database;

    // 1. Check override in platform_sku_prices
    final overrideRows = await db.query(
      'platform_sku_prices',
      where: 'platform_id = ? AND produk_id = ?',
      whereArgs: [platformId, produkId],
    );

    if (overrideRows.isNotEmpty) {
      return (overrideRows.first['override_price'] as num).toDouble();
    }

    // 2. Fallback to platform-wide markup
    final platformRows = await db.query(
      'online_platforms',
      where: 'id = ?',
      whereArgs: [platformId],
    );

    if (platformRows.isEmpty) return defaultPrice;

    final platform = platformRows.first;
    final markupType = platform['markup_type'] as String? ?? 'percentage';
    final markupValue = (platform['markup_value'] as num?)?.toDouble() ?? 0.0;

    if (markupType == 'percentage') {
      return defaultPrice + (defaultPrice * (markupValue / 100.0));
    } else {
      return defaultPrice + markupValue;
    }
  }

  Future<String> createOnlineFoodOrder({
    required String platformId,
    required String platformReferenceId,
    required String customerName,
    required List<OnlineOrderItemRequest> items,
    String? cashierId,
  }) async {
    final db = await _db.database;

    if (items.isEmpty) {
      throw Exception('Daftar item pesanan kosong.');
    }

    final masterOrderId = _uuid.v4();
    final batchId = _uuid.v4();
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final nomorOrder = 'ORD-ONLINE-${now.millisecondsSinceEpoch}';

    return await db.transaction((txn) async {
      double subtotal = 0.0;

      // Create initial batch
      await txn.insert('order_batches', {
        'id': batchId,
        'master_order_id': masterOrderId,
        'batch_number': 1,
        'created_by_cashier_id': cashierId,
        'created_at': nowStr,
      });

      for (final req in items) {
        // Calculate effective price
        double effectivePrice = req.defaultHarga;
        final overrideRows = await txn.query(
          'platform_sku_prices',
          where: 'platform_id = ? AND produk_id = ?',
          whereArgs: [platformId, req.produkId],
        );
        if (overrideRows.isNotEmpty) {
          effectivePrice = (overrideRows.first['override_price'] as num).toDouble();
        } else {
          final platformRows = await txn.query(
            'online_platforms',
            where: 'id = ?',
            whereArgs: [platformId],
          );
          if (platformRows.isNotEmpty) {
            final markupType = platformRows.first['markup_type'] as String? ?? 'percentage';
            final markupValue = (platformRows.first['markup_value'] as num?)?.toDouble() ?? 0.0;
            if (markupType == 'percentage') {
              effectivePrice = req.defaultHarga + (req.defaultHarga * (markupValue / 100.0));
            } else {
              effectivePrice = req.defaultHarga + markupValue;
            }
          }
        }

        final itemSubtotal = effectivePrice * req.qty;
        subtotal += itemSubtotal;

        await txn.insert('order_items', {
          'id': _uuid.v4(),
          'order_id': masterOrderId,
          'master_order_id': masterOrderId,
          'batch_id': batchId,
          'produk_id': req.produkId,
          'produk_nama': req.produkNama,
          'produk_harga': effectivePrice,
          'base_price': req.defaultHarga,
          'effective_price': effectivePrice,
          'qty': req.qty,
          'qty_ordered': req.qty,
          'qty_paid': 0,
          'subtotal': itemSubtotal,
          'catatan': req.catatan,
          'status_cetak': 0,
          'is_cancelled': 0,
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

      await txn.insert('master_orders', {
        'id': masterOrderId,
        'nomor_order': nomorOrder,
        'table_id': null,
        'customer_name': customerName,
        'order_type': 'takeaway_online',
        'platform_id': platformId,
        'platform_reference_id': platformReferenceId,
        'subtotal': subtotal,
        'tax_percentage': taxPercentage,
        'tax_amount': taxAmount,
        'grand_total': grandTotal,
        'total_paid': 0.0,
        'session_status': 'open',
        'payment_status': 'unpaid',
        'last_activity_at': nowStr,
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      return masterOrderId;
    });
  }
}
