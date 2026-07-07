import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/stock_in.dart';
import '../../domain/repositories/stock_repository.dart';

class StockRepositoryImpl implements StockRepository {
  final PosDatabase _db;

  StockRepositoryImpl(this._db);

  @override
  Future<List<StockIn>> getAllStockIn() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*, p.nama as produk_nama 
      FROM stock_in s
      LEFT JOIN products p ON s.produk_id = p.id
      ORDER BY s.created_at DESC
    ''');
    return List.generate(maps.length, (i) => StockIn.fromMap(maps[i]));
  }

  @override
  Future<void> insertStockIn(StockIn stockIn) async {
    final db = await _db.database;
    
    await db.transaction((txn) async {
      // 1. Insert stock_in record
      await txn.insert(
        'stock_in',
        stockIn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // 2. Query current product stock
      final List<Map<String, dynamic>> products = await txn.query(
        'products',
        columns: ['stok'],
        where: 'id = ?',
        whereArgs: [stockIn.produkId],
        limit: 1,
      );

      if (products.isEmpty) {
        throw Exception('Produk dengan ID ${stockIn.produkId} tidak ditemukan');
      }

      final currentStock = products.first['stok'] as int;
      final newStock = currentStock + stockIn.qty;

      // 3. Update product stock
      await txn.update(
        'products',
        {
          'stok': newStock,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [stockIn.produkId],
      );
    });
  }
}
