import 'package:intl/intl.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final PosDatabase _db;
  final Uuid _uuid = const Uuid();

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

  Future<Map<String, List<ProductModifierGroup>>> _loadAllModifierGroups(DatabaseExecutor db) async {
    try {
      final List<Map<String, dynamic>> rawGroups = await db.query(
        'product_modifier_groups',
        orderBy: 'sort_order ASC, created_at ASC',
      );
      final List<Map<String, dynamic>> rawOptions = await db.query(
        'product_modifier_options',
        orderBy: 'sort_order ASC, created_at ASC',
      );

      final Map<String, List<ProductModifierOption>> optionsMap = {};
      for (var optRow in rawOptions) {
        final grpId = optRow['group_id'] as String;
        optionsMap.putIfAbsent(grpId, () => []).add(ProductModifierOption.fromMap(optRow));
      }

      final Map<String, List<ProductModifierGroup>> resultMap = {};
      for (var grpRow in rawGroups) {
        final prodId = grpRow['product_id'] as String;
        final grpId = grpRow['id'] as String;
        final options = optionsMap[grpId] ?? const [];
        resultMap.putIfAbsent(prodId, () => []).add(ProductModifierGroup.fromMap(grpRow, options: options));
      }
      return resultMap;
    } catch (_) {
      return {};
    }
  }

  Future<List<ProductModifierGroup>> _loadModifierGroupsForProduct(DatabaseExecutor db, String productId) async {
    try {
      final List<Map<String, dynamic>> rawGroups = await db.query(
        'product_modifier_groups',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'sort_order ASC, created_at ASC',
      );
      final List<Map<String, dynamic>> rawOptions = await db.query(
        'product_modifier_options',
        where: 'group_id IN (SELECT id FROM product_modifier_groups WHERE product_id = ?)',
        whereArgs: [productId],
        orderBy: 'sort_order ASC, created_at ASC',
      );

      final Map<String, List<ProductModifierOption>> optionsMap = {};
      for (var optRow in rawOptions) {
        final grpId = optRow['group_id'] as String;
        optionsMap.putIfAbsent(grpId, () => []).add(ProductModifierOption.fromMap(optRow));
      }

      return rawGroups.map((grpRow) {
        final grpId = grpRow['id'] as String;
        final options = optionsMap[grpId] ?? const [];
        return ProductModifierGroup.fromMap(grpRow, options: options);
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
    final modifierGroupsMap = await _loadAllModifierGroups(db);

    return List.generate(maps.length, (i) {
      final row = maps[i];
      final prodId = row['id'] as String;
      final pkgItems = packageItemsMap[prodId] ?? const [];
      final modGroups = modifierGroupsMap[prodId] ?? const [];
      return Product.fromMap(row, packageItems: pkgItems, modifierGroups: modGroups);
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
    final modGroups = await _loadModifierGroupsForProduct(db, id);
    return Product.fromMap(maps.first, packageItems: pkgItems, modifierGroups: modGroups);
  }

  @override
  Future<void> insertProduct(
    Product product, {
    DateTime? initialStockDate,
    String? initialStockNotes,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // Record initial stock mutation to stock_in if physical stock > 0
      if (!product.isPackage && product.stok > 0) {
        final dateStr = DateFormat('yyyy-MM-dd').format(initialStockDate ?? DateTime.now());
        final nowStr = DateTime.now().toIso8601String();
        final note = (initialStockNotes != null && initialStockNotes.trim().isNotEmpty)
            ? initialStockNotes.trim()
            : 'Stok Awal';
        await txn.insert('stock_in', {
          'id': _uuid.v4(),
          'produk_id': product.id,
          'type': 'in',
          'qty': product.stok,
          'tanggal': dateStr,
          'catatan': note,
          'created_at': nowStr,
        });
      }

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

      if (product.modifierGroups.isNotEmpty) {
        for (var grp in product.modifierGroups) {
          final grpToInsert = grp.productId.isEmpty ? grp.copyWith(productId: product.id) : grp;
          await txn.insert(
            'product_modifier_groups',
            grpToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          for (var opt in grp.options) {
            final optToInsert = opt.groupId.isEmpty ? opt.copyWith(groupId: grpToInsert.id) : opt;
            await txn.insert(
              'product_modifier_options',
              optToInsert.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
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

      // Refresh modifier groups and options for this product
      // Note: Foreign keys will cascade or we delete options then groups
      final existingGroups = await txn.query(
        'product_modifier_groups',
        columns: ['id'],
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
      for (var grpRow in existingGroups) {
        await txn.delete(
          'product_modifier_options',
          where: 'group_id = ?',
          whereArgs: [grpRow['id']],
        );
      }
      await txn.delete(
        'product_modifier_groups',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );

      if (product.modifierGroups.isNotEmpty) {
        for (var grp in product.modifierGroups) {
          final grpToInsert = grp.productId.isEmpty ? grp.copyWith(productId: product.id) : grp;
          await txn.insert(
            'product_modifier_groups',
            grpToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          for (var opt in grp.options) {
            final optToInsert = opt.groupId.isEmpty ? opt.copyWith(groupId: grpToInsert.id) : opt;
            await txn.insert(
              'product_modifier_options',
              optToInsert.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
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
