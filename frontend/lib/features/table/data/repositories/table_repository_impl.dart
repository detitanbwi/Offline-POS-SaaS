import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/table.dart';
import '../../domain/repositories/table_repository.dart';

import '../../../../core/utils/soft_delete_helper.dart';

class TableRepositoryImpl implements TableRepository {
  final PosDatabase _db;

  TableRepositoryImpl(this._db);

  @override
  Future<List<TableModel>> getAllTables() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tables',
      where: 'is_deleted = 0 AND id NOT IN (?, ?) AND nomor != ?',
      whereArgs: ['TABLE_TAKE_AWAY', 'TAKE_AWAY', 'TA-00'],
      orderBy: 'nomor ASC',
    );
    return List.generate(maps.length, (i) => TableModel.fromMap(maps[i]));
  }

  @override
  Future<TableModel?> getTableById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tables',
      where: 'id = ? AND is_deleted = 0',
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
    if (id == 'TABLE_TAKE_AWAY' || id == 'TAKE_AWAY') return;
    final db = await _db.database;
    final tableMap = await db.query('tables', where: 'id = ?', whereArgs: [id], limit: 1);
    if (tableMap.isNotEmpty) {
      final status = tableMap.first['status'] as int;
      if (status == 1 || status == 4) {
        throw const TableException('Meja tidak bisa dihapus karena sedang terisi pesanan atau tagihan aktif.');
      }
    }
    final activeOrders = await db.query('orders', where: 'table_id = ? AND status = ?', whereArgs: [id, 'draft']);
    if (activeOrders.isNotEmpty) {
      throw const TableException('Meja tidak bisa dihapus karena memiliki pesanan draft yang belum selesai.');
    }

    if (tableMap.isEmpty) return;
    final table = TableModel.fromMap(tableMap.first);
    final tombstoneName = SoftDeleteHelper.makeDeletedName(table.nama);
    final tombstoneNomor = SoftDeleteHelper.makeDeletedName(table.nomor);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'tables',
      {
        'nama': tombstoneName,
        'nomor': tombstoneNomor,
        'is_deleted': 1,
        'deleted_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<TableModel>> getDeletedTables() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tables',
      where: 'is_deleted = 1 AND id NOT IN (?, ?) AND nomor != ?',
      whereArgs: ['TABLE_TAKE_AWAY', 'TAKE_AWAY', 'TA-00'],
      orderBy: 'deleted_at DESC',
    );
    return maps.map((m) {
      final rawNama = m['nama'] as String;
      final rawNomor = m['nomor'] as String;
      final cleanNama = SoftDeleteHelper.cleanDeletedName(rawNama);
      final cleanNomor = SoftDeleteHelper.cleanDeletedName(rawNomor);
      return TableModel.fromMap({...m, 'nama': cleanNama, 'nomor': cleanNomor});
    }).toList();
  }

  @override
  Future<void> restoreTable(String id) async {
    if (id == 'TABLE_TAKE_AWAY' || id == 'TAKE_AWAY') return;
    final db = await _db.database;
    final rows = await db.query('tables', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final rawNama = rows.first['nama'] as String;
    final rawNomor = rows.first['nomor'] as String;
    String cleanNama = SoftDeleteHelper.cleanDeletedName(rawNama);
    String cleanNomor = SoftDeleteHelper.cleanDeletedName(rawNomor);

    if (await isTableNameExists(cleanNama, excludeId: id)) {
      cleanNama = '$cleanNama (Dipulihkan)';
    }
    if (await isTableNumberExists(cleanNomor, excludeId: id)) {
      cleanNomor = '${cleanNomor}_P';
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'tables',
      {
        'nama': cleanNama,
        'nomor': cleanNomor,
        'is_deleted': 0,
        'deleted_at': null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> permanentDeleteTable(String id) async {
    if (id == 'TABLE_TAKE_AWAY' || id == 'TAKE_AWAY') return;
    final db = await _db.database;
    final ords = await db.query('orders', columns: ['id'], where: 'table_id = ?', whereArgs: [id], limit: 1);
    if (ords.isNotEmpty) {
      throw const TableException('Meja tidak dapat dihapus permanen karena masih tercatat dalam riwayat pesanan.');
    }
    final masterOrds = await db.query('master_orders', columns: ['id'], where: 'table_id = ?', whereArgs: [id], limit: 1);
    if (masterOrds.isNotEmpty) {
      throw const TableException('Meja tidak dapat dihapus permanen karena masih tercatat dalam riwayat sesi meja.');
    }

    try {
      await db.delete(
        'tables',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const TableException('Meja tidak dapat dihapus permanen karena masih terkait dengan data lain.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isTableNameExists(String name, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'tables',
      where: excludeId == null ? 'LOWER(nama) = LOWER(?) AND is_deleted = 0' : 'LOWER(nama) = LOWER(?) AND id != ? AND is_deleted = 0',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
    );
    return result.isNotEmpty;
  }

  @override
  Future<bool> isTableNumberExists(String number, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'tables',
      where: excludeId == null ? 'nomor = ? AND is_deleted = 0' : 'nomor = ? AND id != ? AND is_deleted = 0',
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
