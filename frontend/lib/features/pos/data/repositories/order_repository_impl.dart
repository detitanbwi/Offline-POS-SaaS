import 'package:intl/intl.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/print_batch.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final PosDatabase _db;
  final _uuid = const Uuid();
  bool _paymentStatusColumnChecked = false;

  OrderRepositoryImpl(this._db);

  Future<void> _ensurePaymentStatusColumn(DatabaseExecutor txn) async {
    if (_paymentStatusColumnChecked) return;
    try {
      final res = await txn.rawQuery("PRAGMA table_info(orders)");
      bool hasPaymentStatus = res.any((col) => col['name'] == 'payment_status');
      if (!hasPaymentStatus) {
        await txn.execute("ALTER TABLE orders ADD COLUMN payment_status TEXT DEFAULT 'unpaid'");
      }

      final resPrint = await txn.rawQuery("PRAGMA table_info(print_batches)");
      bool hasPrintPaymentStatus = resPrint.any((col) => col['name'] == 'payment_status');
      if (!hasPrintPaymentStatus) {
        await txn.execute("ALTER TABLE print_batches ADD COLUMN payment_status TEXT DEFAULT 'unpaid'");
      }

      final resOrder = await txn.rawQuery("PRAGMA table_info(order_batches)");
      bool hasOrderPaymentStatus = resOrder.any((col) => col['name'] == 'payment_status');
      if (!hasOrderPaymentStatus) {
        await txn.execute("ALTER TABLE order_batches ADD COLUMN payment_status TEXT DEFAULT 'unpaid'");
      }

      _paymentStatusColumnChecked = true;
    } catch (e) {
      _paymentStatusColumnChecked = true;
    }
  }

  @override
  Future<int> getBatchCount(String orderId) async {
    final db = await _db.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM print_batches WHERE order_id = ?',
      [orderId],
    );
    if (res.isNotEmpty) {
      return (res.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getPrintBatches(String orderId) async {
    final db = await _db.database;
    return await db.query(
      'print_batches',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at ASC',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPrintBatchesWithItems(String orderId) async {
    final db = await _db.database;
    final batches = await db.query(
      'print_batches',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at ASC',
    );
    
    List<Map<String, dynamic>> result = [];
    for (var batchRow in batches) {
      final itemsMap = await db.query(
        'order_items',
        where: 'print_batch_id = ?',
        whereArgs: [batchRow['id']],
      );
      final items = itemsMap.map((m) => OrderItemModel.fromMap(m)).toList();
      result.add({
        'batch': PrintBatchModel.fromMap(batchRow),
        'items': items,
      });
    }
    return result;
  }

  @override
  Future<String> recordPrintBatch(String orderId) async {
    final db = await _db.database;
    final batchId = const Uuid().v4();
    await db.insert('print_batches', {
      'id': batchId,
      'order_id': orderId,
      'created_at': DateTime.now().toIso8601String(),
    });
    return batchId;
  }

  @override
  Future<void> markItemsAsPrinted(String orderId, String batchId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // 1. Fetch all unprinted items for this order that are about to be dispatched to kitchen
      final unprintedItems = await txn.query(
        'order_items',
        where: 'order_id = ? AND (print_batch_id IS NULL OR print_batch_id = \'\') AND (is_cancelled IS NULL OR is_cancelled = 0)',
        whereArgs: [orderId],
      );

      // 2. Deduct physical product stock in real time
      final orderRows = await txn.query(
        'orders',
        columns: ['nomor_order', 'table_nama', 'table_nomor', 'customer_name'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      String note = 'Pesanan Dapur';
      if (orderRows.isNotEmpty) {
        final ord = orderRows.first;
        final orderNo = ord['nomor_order'] as String? ?? '';
        final tableNomor = ord['table_nomor'] as String? ?? ord['table_nama'] as String?;
        final custName = ord['customer_name'] as String?;
        if (tableNomor != null && tableNomor.isNotEmpty) {
          note = 'Pesanan Dapur #$orderNo (Meja $tableNomor)';
        } else if (custName != null && custName.isNotEmpty) {
          note = 'Pesanan Dapur #$orderNo ($custName)';
        } else {
          note = 'Pesanan Dapur #$orderNo';
        }
      }

      for (final item in unprintedItems) {
        final produkId = item['produk_id'] as String? ?? '';
        final qty = (item['qty'] as num?)?.toInt() ?? 1;
        await _deductProductStock(txn, produkId, qty, note: note);
      }

      // 3. Mark items as printed and associate with this print batch
      await txn.rawUpdate(
        'UPDATE order_items SET status_cetak = 1, print_batch_id = ? '
        'WHERE order_id = ? AND (print_batch_id IS NULL OR print_batch_id = \'\')',
        [batchId, orderId],
      );
    });
  }

  @override
  Future<void> updatePaymentStatus(String orderId, String status) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await _ensurePaymentStatusColumn(txn);
      await txn.update(
        'orders',
        {
          'payment_status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  @override
  Future<void> updatePrintBatchPaymentStatus(String batchId, String status) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await _ensurePaymentStatusColumn(txn);
      await txn.update(
        'print_batches',
        {'payment_status': status},
        where: 'id = ?',
        whereArgs: [batchId],
      );
    });
  }

  @override
  Future<OrderModel?> getActiveOrderForTable(String tableId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'table_id = ? AND status NOT IN (?, ?)',
      whereArgs: [tableId, 'completed', 'cancelled'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return OrderModel.fromMap(maps.first);
  }

  @override
  Future<OrderModel?> getOrderById(String orderId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return OrderModel.fromMap(maps.first);
  }

  @override
  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    return List.generate(maps.length, (i) => OrderItemModel.fromMap(maps[i]));
  }

  @override
  Future<void> saveOrder(OrderModel order, List<OrderItemModel> items, {bool markAsPrinted = false}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await _ensurePaymentStatusColumn(txn);
      final orderMap = order.toMap();
      // Ensure table_id is NEVER null to satisfy SQLite NOT NULL constraints on legacy/current schemas,
      // and ensure 'TABLE_TAKE_AWAY' sentinel exists in tables table to satisfy FOREIGN KEY constraints.
      if (orderMap['table_id'] == null || (orderMap['table_id'] as String).isEmpty) {
        orderMap['table_id'] = 'TABLE_TAKE_AWAY';
        final checkTable = await txn.query('tables', where: 'id = ?', whereArgs: ['TABLE_TAKE_AWAY']);
        if (checkTable.isEmpty) {
          await txn.insert('tables', {
            'id': 'TABLE_TAKE_AWAY',
            'nama': 'Take Away',
            'nomor': 'TA-00',
            'status': 0,
            'is_deleted': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        final tCheck = await txn.query('tables', where: 'id = ?', whereArgs: [orderMap['table_id']]);
        if (tCheck.isEmpty) {
          orderMap['table_id'] = 'TABLE_TAKE_AWAY';
          final checkTable = await txn.query('tables', where: 'id = ?', whereArgs: ['TABLE_TAKE_AWAY']);
          if (checkTable.isEmpty) {
            await txn.insert('tables', {
              'id': 'TABLE_TAKE_AWAY',
              'nama': 'Take Away',
              'nomor': 'TA-00',
              'status': 0,
              'is_deleted': 1,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      // Verify cashier_id foreign key reference if provided
      if (orderMap['cashier_id'] != null) {
        try {
          final uCheck = await txn.query('cashiers', where: 'id = ?', whereArgs: [orderMap['cashier_id']]);
          if (uCheck.isEmpty) {
            orderMap['cashier_id'] = null;
          }
        } catch (_) {
          orderMap['cashier_id'] = null;
        }
      }

      // 1. Upsert the order header without using replace to avoid CASCADE delete
      final existing = await txn.query('orders', where: 'id = ?', whereArgs: [order.id]);
      if (existing.isEmpty) {
        await txn.insert('orders', orderMap);
      } else {
        await txn.update('orders', orderMap, where: 'id = ?', whereArgs: [order.id]);
      }


      // 2. Delete ALL existing items for this order
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      // 3. Insert all new items
      for (var item in items) {
        await txn.insert(
          'order_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
      }

      // 6. Update the table status to Terisi (1) if tableId is present
      if (order.tableId != null && order.tableId!.isNotEmpty) {
        await txn.update(
          'tables',
          {
            'status': 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [order.tableId],
        );
      }
    });
  }

  @override
  Future<void> cancelOrder(String orderId, String tableId) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // 1. Restore product stock for all printed items in this order
      final orderRows = await txn.query(
        'orders',
        columns: ['nomor_order'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      final orderNo = orderRows.isNotEmpty ? (orderRows.first['nomor_order'] as String? ?? '') : '';
      final note = orderNo.isNotEmpty ? 'Batal Pesanan #$orderNo' : 'Batal Pesanan';

      final items = await txn.query(
        'order_items',
        where: 'order_id = ? AND status_cetak = 1 AND (is_cancelled IS NULL OR is_cancelled = 0)',
        whereArgs: [orderId],
      );
      for (final item in items) {
        final produkId = item['produk_id'] as String? ?? '';
        final qty = (item['qty'] as num?)?.toInt() ?? 1;
        await _restoreProductStock(txn, produkId, qty, note: note);
      }

      // 2. Update order status to 'cancelled'
      await txn.update(
        'orders',
        {
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 3. Set table status back to Empty (0) if tableId exists
      if (tableId.isNotEmpty && tableId != 'TABLE_TAKE_AWAY') {
        await txn.update(
          'tables',
          {
            'status': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }
    });
  }

  @override
  Future<String> generateNextOrderNumber() async {
    final db = await _db.database;
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final searchPattern = '${DateFormat('yyyy-MM-dd').format(now)}%';

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM orders WHERE created_at LIKE ?',
      [searchPattern],
    );

    final count = (result.first['count'] as int) + 1;
    final orderNumSuffix = count.toString().padLeft(4, '0');
    return 'ORD-$dateStr-$orderNumSuffix';
  }

  @override
  Future<Map<String, OrderModel>> getActiveOrdersMap() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'status NOT IN (?, ?)',
      whereArgs: ['completed', 'cancelled'],
    );
    final Map<String, OrderModel> result = {};
    for (var m in maps) {
      final order = OrderModel.fromMap(m);
      if (order.tableId != null && order.tableId!.isNotEmpty) {
        result[order.tableId!] = order;
      }
    }
    return result;
  }

  @override
  Future<List<OrderModel>> getAllDraftOrders() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'status NOT IN (?, ?)',
      whereArgs: ['completed', 'cancelled'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => OrderModel.fromMap(m)).toList();
  }

  @override
  Future<void> completeOrder(String orderId, {String? tableId}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      if (tableId != null && tableId.isNotEmpty) {
        await txn.update(
          'tables',
          {
            'status': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }
    });
  }

  Future<void> _deductProductStock(DatabaseExecutor txn, String produkId, int qty, {String? note}) async {
    if (produkId.isEmpty || produkId.startsWith('manual_') || qty <= 0) return;

    final productRows = await txn.query(
      'products',
      columns: ['id', 'stok', 'nama', 'is_package'],
      where: 'id = ?',
      whereArgs: [produkId],
      limit: 1,
    );
    if (productRows.isEmpty) return;

    final isPackage = (productRows.first['is_package'] as int? ?? 0) == 1;
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final todayStr = nowStr.split('T')[0];

    if (isPackage) {
      final List<Map<String, dynamic>> compRows = await txn.rawQuery('''
        SELECT pi.qty as comp_qty, p.id as comp_id, p.nama as comp_nama, p.stok as comp_stok
        FROM package_items pi
        JOIN products p ON pi.product_id = p.id
        WHERE pi.package_id = ?
      ''', [produkId]);

      for (final comp in compRows) {
        final compStock = comp['comp_stok'] as int? ?? 0;
        if (compStock == -1) continue; // Unlimited non-stock
        final compReqQty = (comp['comp_qty'] as num).toInt() * qty;
        final newCompStock = (compStock - compReqQty).clamp(-999999, 9999999);
        await txn.update(
          'products',
          {'stok': newCompStock, 'updated_at': nowStr},
          where: 'id = ?',
          whereArgs: [comp['comp_id']],
        );
        // Insert into stock_in (Mutasi Stok Keluar)
        await txn.insert('stock_in', {
          'id': _uuid.v4(),
          'produk_id': comp['comp_id'],
          'type': 'out',
          'qty': compReqQty,
          'tanggal': todayStr,
          'catatan': note ?? 'Pesanan Dapur',
          'created_at': nowStr,
        });
      }
    } else {
      final currentStock = productRows.first['stok'] as int? ?? 0;
      if (currentStock == -1) return; // Unlimited non-stock
      final newStock = (currentStock - qty).clamp(-999999, 9999999);
      await txn.update(
        'products',
        {'stok': newStock, 'updated_at': nowStr},
        where: 'id = ?',
        whereArgs: [produkId],
      );
      // Insert into stock_in (Mutasi Stok Keluar)
      await txn.insert('stock_in', {
        'id': _uuid.v4(),
        'produk_id': produkId,
        'type': 'out',
        'qty': qty,
        'tanggal': todayStr,
        'catatan': note ?? 'Pesanan Dapur',
        'created_at': nowStr,
      });
    }
  }

  Future<void> _restoreProductStock(DatabaseExecutor txn, String produkId, int qty, {String? note}) async {
    if (produkId.isEmpty || produkId.startsWith('manual_') || qty <= 0) return;

    final productRows = await txn.query(
      'products',
      columns: ['id', 'stok', 'nama', 'is_package'],
      where: 'id = ?',
      whereArgs: [produkId],
      limit: 1,
    );
    if (productRows.isEmpty) return;

    final isPackage = (productRows.first['is_package'] as int? ?? 0) == 1;
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final todayStr = nowStr.split('T')[0];

    if (isPackage) {
      final List<Map<String, dynamic>> compRows = await txn.rawQuery('''
        SELECT pi.qty as comp_qty, p.id as comp_id, p.nama as comp_nama, p.stok as comp_stok
        FROM package_items pi
        JOIN products p ON pi.product_id = p.id
        WHERE pi.package_id = ?
      ''', [produkId]);

      for (final comp in compRows) {
        final compStock = comp['comp_stok'] as int? ?? 0;
        if (compStock == -1) continue; // Unlimited non-stock
        final compReqQty = (comp['comp_qty'] as num).toInt() * qty;
        final newCompStock = compStock + compReqQty;
        await txn.update(
          'products',
          {'stok': newCompStock, 'updated_at': nowStr},
          where: 'id = ?',
          whereArgs: [comp['comp_id']],
        );
        // Insert into stock_in (Mutasi Stok Masuk / Pengembalian)
        await txn.insert('stock_in', {
          'id': _uuid.v4(),
          'produk_id': comp['comp_id'],
          'type': 'in',
          'qty': compReqQty,
          'tanggal': todayStr,
          'catatan': note ?? 'Batal Pesanan',
          'created_at': nowStr,
        });
      }
    } else {
      final currentStock = productRows.first['stok'] as int? ?? 0;
      if (currentStock == -1) return; // Unlimited non-stock
      final newStock = currentStock + qty;
      await txn.update(
        'products',
        {'stok': newStock, 'updated_at': nowStr},
        where: 'id = ?',
        whereArgs: [produkId],
      );
      // Insert into stock_in (Mutasi Stok Masuk / Pengembalian)
      await txn.insert('stock_in', {
        'id': _uuid.v4(),
        'produk_id': produkId,
        'type': 'in',
        'qty': qty,
        'tanggal': todayStr,
        'catatan': note ?? 'Batal Pesanan',
        'created_at': nowStr,
      });
    }
  }

  Future<void> _recalculateOrderTotals(DatabaseExecutor txn, String orderId) async {
    final orderMap = await txn.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
    if (orderMap.isEmpty) return;

    final taxPercentage = (orderMap.first['tax_percentage'] as num?)?.toDouble() ?? 0.0;
    final serviceRate = (orderMap.first['service_charge_percentage'] as num?)?.toDouble() ?? 0.0;
    final isAfterTax = (orderMap.first['service_charge_after_tax'] as int?) == 1;
    final tableId = orderMap.first['table_id'] as String?;

    final activeItems = await txn.query(
      'order_items',
      where: 'order_id = ? AND (is_cancelled IS NULL OR is_cancelled = 0)',
      whereArgs: [orderId],
    );

    // If ALL items in this order have been cancelled, mark order as cancelled and free the table
    if (activeItems.isEmpty) {
      await txn.update(
        'orders',
        {
          'status': 'cancelled',
          'subtotal': 0.0,
          'service_charge_amount': 0.0,
          'tax_amount': 0.0,
          'grand_total': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      if (tableId != null && tableId.isNotEmpty && tableId != 'TABLE_TAKE_AWAY') {
        final otherActiveOrders = await txn.query(
          'orders',
          where: 'table_id = ? AND id != ? AND status NOT IN (?, ?, ?)',
          whereArgs: [tableId, orderId, 'completed', 'cancelled', 'cleared'],
        );
        if (otherActiveOrders.isEmpty) {
          await txn.update(
            'tables',
            {
              'status': 0,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [tableId],
          );
        }
      }
      return;
    }

    double subtotal = 0.0;
    for (var item in activeItems) {
      subtotal += (item['subtotal'] as num).toDouble();
    }

    double serviceAmount = 0.0;
    double taxAmount = 0.0;
    if (isAfterTax) {
      taxAmount = (subtotal * (taxPercentage / 100)).ceilToDouble();
      serviceAmount = ((subtotal + taxAmount) * (serviceRate / 100)).ceilToDouble();
    } else {
      serviceAmount = (subtotal * (serviceRate / 100)).ceilToDouble();
      taxAmount = ((subtotal + serviceAmount) * (taxPercentage / 100)).ceilToDouble();
    }

    final grandTotal = subtotal + serviceAmount + taxAmount;

    await txn.update(
      'orders',
      {
        'subtotal': subtotal,
        'service_charge_amount': serviceAmount,
        'tax_amount': taxAmount,
        'grand_total': grandTotal,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> transferOrderTable(
    String orderId,
    String oldTableId,
    String newTableId,
    String newTableName,
    String newTableNomor,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'table_id': newTableId,
          'table_nama': newTableName,
          'table_nomor': newTableNomor,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      await txn.update(
        'tables',
        {
          'status': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [oldTableId],
      );

      await txn.update(
        'tables',
        {
          'status': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [newTableId],
      );
    });
  }

  @override
  Future<void> cancelOrderItem(String itemId, String reason) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final items = await txn.query('order_items', where: 'id = ?', whereArgs: [itemId], limit: 1);
      if (items.isEmpty) return;
      final item = items.first;
      final orderId = item['order_id'] as String;
      final statusCetak = (item['status_cetak'] as num?)?.toInt() ?? 0;
      final isAlreadyCancelled = (item['is_cancelled'] as num?)?.toInt() ?? 0;

      // 1. Restore product stock if item was already dispatched to kitchen
      if (statusCetak == 1 && isAlreadyCancelled == 0) {
        final orderRows = await txn.query('orders', columns: ['nomor_order'], where: 'id = ?', whereArgs: [orderId], limit: 1);
        final orderNo = orderRows.isNotEmpty ? (orderRows.first['nomor_order'] as String? ?? '') : '';
        final note = 'Batal Item ${orderNo.isNotEmpty ? '#$orderNo' : ''}${reason.isNotEmpty ? ' ($reason)' : ''}'.trim();

        final produkId = item['produk_id'] as String? ?? '';
        final qty = (item['qty'] as num?)?.toInt() ?? 1;
        await _restoreProductStock(txn, produkId, qty, note: note);
      }

      // 2. Mark item as cancelled
      await txn.update(
        'order_items',
        {
          'is_cancelled': 1,
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancelled_reason': reason,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      // 3. Recalculate totals and free table if empty
      await _recalculateOrderTotals(txn, orderId);
    });
  }

  @override
  Future<void> cancelOrderBatch(String batchId, String reason) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final items = await txn.query('order_items', where: 'print_batch_id = ?', whereArgs: [batchId]);
      if (items.isEmpty) return;
      final orderId = items.first['order_id'] as String;

      final orderRows = await txn.query('orders', columns: ['nomor_order'], where: 'id = ?', whereArgs: [orderId], limit: 1);
      final orderNo = orderRows.isNotEmpty ? (orderRows.first['nomor_order'] as String? ?? '') : '';
      final note = 'Batal Batch ${orderNo.isNotEmpty ? '#$orderNo' : ''}${reason.isNotEmpty ? ' ($reason)' : ''}'.trim();

      // 1. Restore product stock for all items in this batch that were dispatched to kitchen
      for (final item in items) {
        final statusCetak = (item['status_cetak'] as num?)?.toInt() ?? 0;
        final isAlreadyCancelled = (item['is_cancelled'] as num?)?.toInt() ?? 0;
        if (statusCetak == 1 && isAlreadyCancelled == 0) {
          final produkId = item['produk_id'] as String? ?? '';
          final qty = (item['qty'] as num?)?.toInt() ?? 1;
          await _restoreProductStock(txn, produkId, qty, note: note);
        }
      }

      // 2. Mark items in this batch as cancelled
      await txn.update(
        'order_items',
        {
          'is_cancelled': 1,
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancelled_reason': reason,
        },
        where: 'print_batch_id = ?',
        whereArgs: [batchId],
      );

      // 3. Recalculate totals and free table if empty
      await _recalculateOrderTotals(txn, orderId);
    });
  }

  @override
  Future<void> clearTableOnly(String orderId, String tableId, String reason) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // 1. Reset status meja ke 0 (Kosong)
      await txn.update(
        'tables',
        {
          'status': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [tableId],
      );

      // 2. Tandai specific order sebagai cleared
      if (orderId.isNotEmpty) {
        await txn.update(
          'orders',
          {
            'status': 'cleared',
            'clear_table_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }

      // 3. Tandai semua order aktif lain pada meja ini sebagai cleared
      if (tableId.isNotEmpty) {
        await txn.update(
          'orders',
          {
            'status': 'cleared',
            'clear_table_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'table_id = ? AND status NOT IN (?, ?)',
          whereArgs: [tableId, 'completed', 'cancelled'],
        );
      }
    });
  }

  @override
  Future<void> markTableBillPrinted(String tableId) async {
    final db = await _db.database;
    await db.update(
      'tables',
      {
        'status': 4,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [tableId],
    );
  }

  @override
  Future<void> markOrderBillPrinted(String orderId) async {
    final db = await _db.database;
    await db.update(
      'orders',
      {
        'is_bill_printed': 1,
        'bill_printed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}

