import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../../../core/utils/soft_delete_helper.dart';
import '../../domain/models/cashier.dart';
import '../../domain/repositories/cashier_repository.dart';

class CashierRepositoryImpl implements CashierRepository {
  final PosDatabase _db;

  CashierRepositoryImpl(this._db);

  @override
  Future<List<CashierModel>> getAllCashiers() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: 'is_deleted = 0',
      orderBy: 'nama ASC',
    );
    return List.generate(maps.length, (i) => CashierModel.fromMap(maps[i]));
  }

  @override
  Future<CashierModel?> getCashierById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CashierModel.fromMap(maps.first);
  }

  @override
  Future<CashierModel?> getCashierByPin(String hashedPin) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: 'pin = ? AND status = 1 AND is_deleted = 0',
      whereArgs: [hashedPin],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CashierModel.fromMap(maps.first);
  }

  @override
  Future<CashierModel?> getCashierByNameAndPin(String name, String hashedPin) async {
    final db = await _db.database;
    final cleanInput = name.toLowerCase().trim();
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: '(LOWER(username) = ? OR LOWER(nama) = ?) AND pin = ? AND status = 1 AND is_deleted = 0',
      whereArgs: [cleanInput, cleanInput, hashedPin],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CashierModel.fromMap(maps.first);
  }

  @override
  Future<void> saveCashier(CashierModel cashier) async {
    final db = await _db.database;
    await db.insert(
      'cashiers',
      cashier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateStatus(String id, int status) async {
    final db = await _db.database;
    await db.update(
      'cashiers',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> softDelete(String id) async {
    final db = await _db.database;
    final cashiers = await db.query('cashiers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (cashiers.isEmpty) return;
    final cashier = CashierModel.fromMap(cashiers.first);
    final tombstoneNama = SoftDeleteHelper.makeDeletedName(cashier.nama);
    final tombstoneUsername = SoftDeleteHelper.makeDeletedName(cashier.username);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'cashiers',
      {
        'nama': tombstoneNama,
        'username': tombstoneUsername,
        'is_deleted': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<CashierModel>> getDeletedCashiers() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: 'is_deleted = 1',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) {
      final rawNama = m['nama'] as String;
      final rawUser = m['username'] as String? ?? '';
      final cleanNama = SoftDeleteHelper.cleanDeletedName(rawNama);
      final cleanUser = SoftDeleteHelper.cleanDeletedName(rawUser);
      return CashierModel.fromMap({...m, 'nama': cleanNama, 'username': cleanUser});
    }).toList();
  }

  @override
  Future<void> restoreCashier(String id) async {
    final db = await _db.database;
    final rows = await db.query('cashiers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final rawNama = rows.first['nama'] as String;
    final rawUser = rows.first['username'] as String? ?? '';
    String cleanNama = SoftDeleteHelper.cleanDeletedName(rawNama);
    String cleanUser = SoftDeleteHelper.cleanDeletedName(rawUser);

    if (await isNameExists(cleanNama, excludeId: id)) {
      cleanNama = '$cleanNama (Dipulihkan)';
    }
    if (await isUsernameExists(cleanUser, excludeId: id)) {
      cleanUser = '${cleanUser}_p';
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'cashiers',
      {
        'nama': cleanNama,
        'username': cleanUser,
        'is_deleted': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> permanentDeleteCashier(String id) async {
    final db = await _db.database;
    // Check if cashier has transactions
    final txns = await db.query('transactions', columns: ['id'], where: 'cashier_id = ?', whereArgs: [id], limit: 1);
    if (txns.isNotEmpty) {
      throw const CashierException('Kasir tidak dapat dihapus permanen karena masih tercatat dalam riwayat transaksi penjualan.');
    }
    final ords = await db.query('orders', columns: ['id'], where: 'cashier_id = ?', whereArgs: [id], limit: 1);
    if (ords.isNotEmpty) {
      throw const CashierException('Kasir tidak dapat dihapus permanen karena masih tercatat dalam riwayat pesanan.');
    }

    try {
      await db.delete(
        'cashiers',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const CashierException('Kasir tidak dapat dihapus permanen karena masih terkait dengan data lain.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isNameExists(String name, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: excludeId == null ? 'LOWER(nama) = ? AND is_deleted = 0' : 'LOWER(nama) = ? AND id != ? AND is_deleted = 0',
      whereArgs: excludeId == null ? [name.toLowerCase().trim()] : [name.toLowerCase().trim(), excludeId],
    );
    return maps.isNotEmpty;
  }

  @override
  Future<bool> isUsernameExists(String username, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: excludeId == null ? 'LOWER(username) = ? AND is_deleted = 0' : 'LOWER(username) = ? AND id != ? AND is_deleted = 0',
      whereArgs: excludeId == null ? [username.toLowerCase().trim()] : [username.toLowerCase().trim(), excludeId],
    );
    return maps.isNotEmpty;
  }

  @override
  Future<bool> isPinExists(String hashedPin, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: excludeId == null ? 'pin = ? AND is_deleted = 0' : 'pin = ? AND id != ? AND is_deleted = 0',
      whereArgs: excludeId == null ? [hashedPin] : [hashedPin, excludeId],
    );
    return maps.isNotEmpty;
  }
}

class CashierException implements Exception {
  final String message;
  const CashierException(this.message);
  @override
  String toString() => message;
}
