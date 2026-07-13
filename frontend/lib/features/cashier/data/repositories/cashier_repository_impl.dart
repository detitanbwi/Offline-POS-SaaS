import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
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
    final List<Map<String, dynamic>> maps = await db.query(
      'cashiers',
      where: 'LOWER(nama) = ? AND pin = ? AND status = 1 AND is_deleted = 0',
      whereArgs: [name.toLowerCase().trim(), hashedPin],
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
    await db.update(
      'cashiers',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
