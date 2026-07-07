import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final PosDatabase _db;

  TransactionRepositoryImpl(this._db);

  @override
  Future<List<TransactionHeader>> getAllTransactions() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => TransactionHeader.fromMap(maps[i]));
  }

  @override
  Future<List<TransactionItem>> getTransactionItems(String transactionId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

  @override
  Future<void> saveTransaction(TransactionHeader header, List<TransactionItem> items) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // 1. Insert header
      await txn.insert(
        'transactions',
        header.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // 2. Loop through items
      for (var item in items) {
        // Insert transaction item details
        await txn.insert(
          'transaction_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        // 3. Deduct product stock
        final List<Map<String, dynamic>> productResult = await txn.query(
          'products',
          columns: ['stok', 'nama'],
          where: 'id = ?',
          whereArgs: [item.produkId],
          limit: 1,
        );

        if (productResult.isEmpty) {
          throw Exception('Produk "${item.produkNama}" tidak ditemukan.');
        }

        final currentStock = productResult.first['stok'] as int;
        final productName = productResult.first['nama'] as String;
        final newStock = currentStock - item.qty;

        if (newStock < 0) {
          throw Exception('Gagal menyimpan transaksi: Stok untuk produk "$productName" tidak mencukupi.');
        }

        await txn.update(
          'products',
          {
            'stok': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.produkId],
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
      'SELECT COUNT(*) as count FROM transactions WHERE created_at LIKE ?',
      [searchPattern],
    );

    final count = (result.first['count'] as int) + 1;
    final orderNumSuffix = count.toString().padLeft(4, '0');
    return 'TRX-$dateStr-$orderNumSuffix';
  }
}
