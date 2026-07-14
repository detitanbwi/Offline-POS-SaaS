import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/tax_setting.dart';
import '../../domain/repositories/tax_repository.dart';

class TaxRepositoryImpl implements TaxRepository {
  final PosDatabase _db;

  TaxRepositoryImpl(this._db);

  @override
  Future<TaxSetting> getTaxSetting() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tax_settings',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isEmpty) {
      // Fallback fallback if empty (should already be seeded)
      final fallback = TaxSetting(percentage: 11.0, updatedAt: DateTime.now());
      await db.insert('tax_settings', fallback.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return fallback;
    }
    return TaxSetting.fromMap(maps.first);
  }

  @override
  Future<void> updateTaxSetting(TaxSetting taxSetting) async {
    final db = await _db.database;
    await db.insert(
      'tax_settings',
      taxSetting.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
