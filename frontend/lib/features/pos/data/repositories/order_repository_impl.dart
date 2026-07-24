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
      // 1. Read existing items from DB keyed by produk_id to preserve their id, print_batch_id, status_cetak
      final List<Map<String, dynamic>> existingRows = await txn.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      final Map<String, Map<String, dynamic>> existingByProdukId = {};
      for (var row in existingRows) {
        existingByProdukId[row['produk_id'] as String] = row;
      }

      // 2. Upsert the order header
      await txn.insert(
        'orders',
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Determine which produk_ids are in the new cart
      final Set<String> newProdukIds = items.map((i) => i.produkId).toSet();

      // 4. Delete items that were removed from the cart
      for (var existingProdukId in existingByProdukId.keys) {
        if (!newProdukIds.contains(existingProdukId)) {
          await txn.delete(
            'order_items',
            where: 'order_id = ? AND produk_id = ?',
            whereArgs: [order.id, existingProdukId],
          );
        }
      }

      // 5. Upsert items: UPDATE existing, INSERT new
      for (var item in items) {
        final existing = existingByProdukId[item.produkId];

        if (existing != null) {
          // Item already exists in DB → UPDATE qty, subtotal, catatan only
          // Preserve: id, print_batch_id, status_cetak
          final Map<String, dynamic> updateData = {
            'qty': item.qty,
            'subtotal': item.subtotal,
            'catatan': item.catatan,
          };

          // If qty increased, the new qty portion is "unprinted" — but we keep
          // the existing print_batch_id because the whole item row is one entry.
          // The difference detection (itemsToPrint) in the notifier handles
          // what to send to the kitchen. We only clear print status if markAsPrinted is false
          // and qty changed (new portion not yet printed).
          if (item.qty != (existing['qty'] as int)) {
            // Qty changed → mark as unprinted so it gets picked up by markItemsAsPrinted later
            // But only clear if there are NEW items to print (qty increased)
            if (item.qty > (existing['qty'] as int)) {
              updateData['status_cetak'] = 0;
              updateData['print_batch_id'] = null;
            }
          }

          await txn.update(
            'order_items',
            updateData,
            where: 'order_id = ? AND produk_id = ?',
            whereArgs: [order.id, item.produkId],
          );
        } else {
          // New item → INSERT with status_cetak=0, print_batch_id=null
          final newItem = item.copyWith(
            statusCetak: 0,
            printBatchId: null,
          );
          await txn.insert(
            'order_items',
            newItem.toMap(),
            conflictAlgorithm: ConflictAlgorithm.fail,
          );
        }
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
  Future<void> completeOrder(String orderId) async {
    final db = await _db.database;
    await db.update(
      'orders',
      {
        'status': 'completed',
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
}

