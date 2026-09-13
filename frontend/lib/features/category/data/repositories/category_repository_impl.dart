import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/category.dart';
import '../../domain/repositories/category_repository.dart';

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
    // Cek apakah ada kategori dengan nama yang sama yang telah di-soft-delete sebelumnya
    final deleted = await db.query(
      'categories',
      where: 'LOWER(nama) = LOWER(?) AND is_deleted = 1',
      whereArgs: [category.nama],
      limit: 1,
    );

    if (deleted.isNotEmpty) {
      final oldId = deleted.first['id'] as String;
      await db.update(
        'categories',
        {
          'nama': category.nama,
          'status': category.status,
          'image': category.image,
          'is_deleted': 0,
          'deleted_at': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [oldId],
      );
      return;
    }

    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updateCategory(Category category) async {
    final db = await _db.database;
    // Jika ada kategori lain yang di-soft-delete dengan nama yang sama, bersihkan agar tidak konflik UNIQUE constraint
    final conflicting = await db.query(
      'categories',
      where: 'LOWER(nama) = LOWER(?) AND id != ? AND is_deleted = 1',
      whereArgs: [category.nama, category.id],
      limit: 1,
    );
    if (conflicting.isNotEmpty) {
      await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [conflicting.first['id']],
      );
    }

    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    final db = await _db.database;
    try {
      await db.update(
        'categories',
        {
          'is_deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const ForeignKeyException('Kategori tidak bisa dihapus karena masih digunakan oleh produk.');
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
