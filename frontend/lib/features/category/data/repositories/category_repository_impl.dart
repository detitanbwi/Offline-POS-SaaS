import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/category.dart';
import '../../domain/repositories/category_repository.dart';

import '../../../../core/utils/soft_delete_helper.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final PosDatabase _db;

  CategoryRepositoryImpl(this._db);

  @override
  Future<List<Category>> getAllCategories() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'is_deleted = 0',
      orderBy: 'nama ASC',
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  @override
  Future<void> insertCategory(Category category) async {
    final db = await _db.database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updateCategory(Category category) async {
    final db = await _db.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> toggleCategoryStatus(String id, int status) async {
    final db = await _db.database;
    await db.update(
      'categories',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    final db = await _db.database;
    final cat = await getCategoryById(id);
    if (cat == null) return;
    
    // Tag name with tombstone to avoid UNIQUE constraint collision if a new category is made with the same name
    final tombstoneName = SoftDeleteHelper.makeDeletedName(cat.nama);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'categories',
      {
        'nama': tombstoneName,
        'is_deleted': 1,
        'deleted_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Category>> getDeletedCategories() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return maps.map((m) {
      final rawNama = m['nama'] as String;
      final clean = SoftDeleteHelper.cleanDeletedName(rawNama);
      return Category.fromMap({...m, 'nama': clean});
    }).toList();
  }

  @override
  Future<void> restoreCategory(String id) async {
    final db = await _db.database;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final rawNama = rows.first['nama'] as String;
    String cleanName = SoftDeleteHelper.cleanDeletedName(rawNama);

    // If cleanName already taken by an active category, append suffix
    final exists = await isCategoryNameExists(cleanName, excludeId: id);
    if (exists) {
      cleanName = '$cleanName (Dipulihkan)';
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'categories',
      {
        'nama': cleanName,
        'is_deleted': 0,
        'deleted_at': null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> permanentDeleteCategory(String id) async {
    final db = await _db.database;
    // Cek apakah masih ada produk yang menggunakan kategori ini
    final products = await db.query(
      'products',
      columns: ['id'],
      where: 'kategori_id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (products.isNotEmpty) {
      throw const ForeignKeyException('Kategori tidak dapat dihapus permanen karena masih digunakan oleh produk.');
    }

    try {
      await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const ForeignKeyException('Kategori tidak dapat dihapus permanen karena masih terkait dengan data lain.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isCategoryNameExists(String name, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'categories',
      where: excludeId == null ? 'LOWER(nama) = LOWER(?) AND is_deleted = 0' : 'LOWER(nama) = LOWER(?) AND id != ? AND is_deleted = 0',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
    );
    return result.isNotEmpty;
  }
}

class ForeignKeyException implements Exception {
  final String message;
  const ForeignKeyException(this.message);
  @override
  String toString() => message;
}
