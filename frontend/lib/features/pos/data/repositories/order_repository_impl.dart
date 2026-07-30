import 'package:intl/intl.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final PosDatabase _db;

  OrderRepositoryImpl(this._db);

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
  Future<OrderModel?> getActiveOrderForTable(String tableId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'table_id = ? AND status = ?',
      whereArgs: [tableId, 'draft'],
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
      // 1. Upsert the order header without using replace to avoid CASCADE delete
      final existing = await txn.query('orders', where: 'id = ?', whereArgs: [order.id]);
      if (existing.isEmpty) {
        await txn.insert('orders', order.toMap());
      } else {
        await txn.update('orders', order.toMap(), where: 'id = ?', whereArgs: [order.id]);
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
      where: 'status = ?',
      whereArgs: ['draft'],
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

    final activeItems = await txn.query(
      'order_items',
      where: 'order_id = ? AND (is_cancelled IS NULL OR is_cancelled = 0)',
      whereArgs: [orderId],
    );

    double subtotal = 0.0;
    for (var item in activeItems) {
      subtotal += (item['subtotal'] as num).toDouble();
    }

    final taxAmount = subtotal * (taxPercentage / 100);
    final grandTotal = subtotal + taxAmount;

    await txn.update(
      'orders',
      {
        'subtotal': subtotal,
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
      await txn.update(
        'tables',
        {
          'status': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [tableId],
      );

      await txn.update(
        'orders',
        {
          'clear_table_reason': reason,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
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
}

