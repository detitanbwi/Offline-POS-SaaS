import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final PosDatabase _db;

  ProductRepositoryImpl(this._db);

  Future<Map<String, List<PackageItem>>> _loadAllPackageItems(DatabaseExecutor db) async {
    try {
      final List<Map<String, dynamic>> rawItems = await db.rawQuery('''
        SELECT pi.*, p.nama as product_nama, p.harga as product_harga, p.stok as product_stok, p.kategori_id, c.nama as kategori_nama
        FROM package_items pi
        JOIN products p ON pi.product_id = p.id
        LEFT JOIN categories c ON p.kategori_id = c.id
        ORDER BY pi.created_at ASC
      ''');

      final Map<String, List<PackageItem>> resultMap = {};
      for (var row in rawItems) {
        final pkgId = row['package_id'] as String;
        final item = PackageItem.fromMap(
          row,
          productName: row['product_nama'] as String?,
          productPrice: (row['product_harga'] as num?)?.toDouble(),
          productStock: row['product_stok'] as int?,
          categoryId: row['kategori_id'] as String?,
          categoryName: row['kategori_nama'] as String?,
        );
        resultMap.putIfAbsent(pkgId, () => []).add(item);
      }
      return resultMap;
    } catch (_) {
      return {};
    }
  }

  Future<List<PackageItem>> _loadPackageItemsForProduct(DatabaseExecutor db, String packageId) async {
    try {
      final List<Map<String, dynamic>> rawItems = await db.rawQuery('''
        SELECT pi.*, p.nama as product_nama, p.harga as product_harga, p.stok as product_stok, p.kategori_id, c.nama as kategori_nama
        FROM package_items pi
        JOIN products p ON pi.product_id = p.id
        LEFT JOIN categories c ON p.kategori_id = c.id
        WHERE pi.package_id = ?
        ORDER BY pi.created_at ASC
      ''', [packageId]);

      return rawItems.map((row) {
        return PackageItem.fromMap(
          row,
          productName: row['product_nama'] as String?,
          productPrice: (row['product_harga'] as num?)?.toDouble(),
          productStock: row['product_stok'] as int?,
          categoryId: row['kategori_id'] as String?,
          categoryName: row['kategori_nama'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Product>> getAllProducts() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.nama as kategori_nama 
      FROM products p 
      LEFT JOIN categories c ON p.kategori_id = c.id
      WHERE p.is_deleted = 0
      ORDER BY p.nama ASC
    ''');

    final packageItemsMap = await _loadAllPackageItems(db);

    return List.generate(maps.length, (i) {
      final row = maps[i];
      final prodId = row['id'] as String;
      final pkgItems = packageItemsMap[prodId] ?? const [];
      return Product.fromMap(row, packageItems: pkgItems);
    });
  }

  @override
  Future<Product?> getProductById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.nama as kategori_nama 
      FROM products p 
      LEFT JOIN categories c ON p.kategori_id = c.id
      WHERE p.id = ? AND p.is_deleted = 0
      LIMIT 1
    ''', [id]);
    if (maps.isEmpty) return null;

    final pkgItems = await _loadPackageItemsForProduct(db, id);
    return Product.fromMap(maps.first, packageItems: pkgItems);
  }

  @override
  Future<void> insertProduct(Product product) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      if (product.isPackage && product.packageItems.isNotEmpty) {
        for (var item in product.packageItems) {
          final itemToInsert = item.packageId.isEmpty ? item.copyWith(packageId: product.id) : item;
          await txn.insert(
            'package_items',
            itemToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  @override
  Future<void> updateProduct(Product product) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Refresh package items for this product
      await txn.delete(
        'package_items',
        where: 'package_id = ?',
        whereArgs: [product.id],
      );

      if (product.isPackage && product.packageItems.isNotEmpty) {
        for (var item in product.packageItems) {
          final itemToInsert = item.packageId.isEmpty ? item.copyWith(packageId: product.id) : item;
          await txn.insert(
            'package_items',
            itemToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _db.database;
    try {
      await db.update(
        'products',
        {
          'is_deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
        },
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
      where: excludeId == null ? 'LOWER(nama) = LOWER(?) AND is_deleted = 0' : 'LOWER(nama) = LOWER(?) AND id != ? AND is_deleted = 0',
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
        columns: ['stok', 'is_package'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) return;
      final isPkg = (maps.first['is_package'] as int? ?? 0) == 1;
      if (isPkg) {
        // Packages don't have direct static physical stock to modify with updateStock
        return;
      }
      final currentStock = maps.first['stok'] as int;
      if (currentStock == -1) return; // unlimited

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
