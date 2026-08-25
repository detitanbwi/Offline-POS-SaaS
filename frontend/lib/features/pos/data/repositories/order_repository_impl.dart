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
    await db.rawUpdate(
      'UPDATE order_items SET status_cetak = 1, print_batch_id = ? '
      'WHERE order_id = ? AND (print_batch_id IS NULL OR print_batch_id = \'\')',
      [batchId, orderId],
    );
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
      // 1. Update order status to 'cancelled'
      await txn.update(
        'orders',
        {
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 2. Set table status back to Empty (0) if tableId exists
      if (tableId.isNotEmpty) {
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

  Future<void> _recalculateOrderTotals(DatabaseExecutor txn, String orderId) async {
    final orderMap = await txn.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
    if (orderMap.isEmpty) return;

    final taxPercentage = (orderMap.first['tax_percentage'] as num?)?.toDouble() ?? 0.0;
    final serviceRate = (orderMap.first['service_charge_percentage'] as num?)?.toDouble() ?? 0.0;
    final isAfterTax = (orderMap.first['service_charge_after_tax'] as int?) == 1;

    final activeItems = await txn.query(
      'order_items',
      where: 'order_id = ? AND (is_cancelled IS NULL OR is_cancelled = 0)',
      whereArgs: [orderId],
    );

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
      final orderId = items.first['order_id'] as String;

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

