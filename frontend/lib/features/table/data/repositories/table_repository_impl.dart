import 'package:sqflite/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/table.dart';
import '../../domain/repositories/table_repository.dart';

class TableRepositoryImpl implements TableRepository {
  final PosDatabase _db;

  TableRepositoryImpl(this._db);

  @override
  Future<List<TableModel>> getAllTables() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tables',
      orderBy: 'nomor ASC',
    );
    return List.generate(maps.length, (i) => TableModel.fromMap(maps[i]));
  }

  @override
  Future<TableModel?> getTableById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tables',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TableModel.fromMap(maps.first);
  }

  @override
  Future<void> saveTable(TableModel table) async {
    final db = await _db.database;
    await db.insert(
      'tables',
      table.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteTable(String id) async {
    final db = await _db.database;
    try {
      await db.delete(
        'tables',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const TableException('Meja tidak bisa dihapus karena masih digunakan dalam transaksi/order.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isTableNameExists(String name, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'tables',
      where: excludeId == null ? 'LOWER(nama) = LOWER(?)' : 'LOWER(nama) = LOWER(?) AND id != ?',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
    );
    return result.isNotEmpty;
  }

  @override
  Future<bool> isTableNumberExists(String number, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'tables',
      where: excludeId == null ? 'nomor = ?' : 'nomor = ? AND id != ?',
      whereArgs: excludeId == null ? [number] : [number, excludeId],
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> updateTableStatus(String id, int status) async {
    final db = await _db.database;
    await db.update(
      'tables',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class TableException implements Exception {
  final String message;
  const TableException(this.message);
  @override
  String toString() => message;
}
