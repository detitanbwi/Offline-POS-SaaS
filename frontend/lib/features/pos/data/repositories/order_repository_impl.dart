import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final PosDatabase _db;

  OrderRepositoryImpl(this._db);

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
      // 1. Check existing printed status for the items to preserve it
      final List<Map<String, dynamic>> existingItems = await txn.query(
        'order_items',
        columns: ['produk_id', 'status_cetak', 'print_batch_id'],
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      final Map<String, Map<String, dynamic>> printStatusMap = {};
      for (var row in existingItems) {
        printStatusMap[row['produk_id'] as String] = {
          'status_cetak': row['status_cetak'] as int,
          'print_batch_id': row['print_batch_id'] as String?,
        };
      }

      // 2. Insert or update the order header
      await txn.insert(
        'orders',
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Delete old items
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      // 4. Insert new items preserving print status if matched
      for (var item in items) {
        int finalStatusCetak = markAsPrinted ? 1 : item.statusCetak;
        String? finalPrintBatchId = item.printBatchId;

        // If this product was already in the order, and we are not marking all as printed, preserve status
        if (!markAsPrinted && printStatusMap.containsKey(item.produkId)) {
          finalStatusCetak = printStatusMap[item.produkId]!['status_cetak'] as int;
          finalPrintBatchId = printStatusMap[item.produkId]!['print_batch_id'] as String?;
        }

        final finalItem = item.copyWith(
          statusCetak: finalStatusCetak,
          printBatchId: finalPrintBatchId,
        );

        await txn.insert(
          'order_items',
          finalItem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
      }

      // 5. Update the table status to Terisi (1)
      await txn.update(
        'tables',
        {
          'status': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [order.tableId],
      );
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

      // 2. Set table status back to Empty (0)
      await txn.update(
        'tables',
        {
          'status': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [tableId],
      );
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
      result[order.tableId] = order;
    }
    return result;
  }

  @override
  Future<void> completeOrder(String orderId, String tableId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // 1. Update order status to completed
      await txn.update(
        'orders',
        {
          'status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 2. Set table status back to Empty (0)
      await txn.update(
        'tables',
        {
          'status': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [tableId],
      );
    });
  }
}
