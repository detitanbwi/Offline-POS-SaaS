import 'package:sqflite/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final PosDatabase _db;

  ProductRepositoryImpl(this._db);

  @override
  Future<List<Product>> getAllProducts() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.nama as kategori_nama 
      FROM products p 
      LEFT JOIN categories c ON p.kategori_id = c.id
      ORDER BY p.nama ASC
    ''');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  @override
  Future<Product?> getProductById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.nama as kategori_nama 
      FROM products p 
      LEFT JOIN categories c ON p.kategori_id = c.id
      WHERE p.id = ?
      LIMIT 1
    ''', [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  @override
  Future<void> insertProduct(Product product) async {
    final db = await _db.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updateProduct(Product product) async {
    final db = await _db.database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _db.database;
    try {
      await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const ProductForeignKeyException('Produk tidak bisa dihapus karena terdapat transaksi terkait.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isProductNameExists(String name, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'products',
      where: excludeId == null ? 'LOWER(nama) = LOWER(?)' : 'LOWER(nama) = LOWER(?) AND id != ?',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> updateStock(String id, int quantityChange) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> maps = await txn.query(
        'products',
        columns: ['stok'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) return;
      final currentStock = maps.first['stok'] as int;
      final newStock = currentStock + quantityChange;
      await txn.update(
        'products',
        {'stok': newStock, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}

class ProductForeignKeyException implements Exception {
  final String message;
  const ProductForeignKeyException(this.message);
  @override
  String toString() => message;
}
