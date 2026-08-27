import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/printer_config.dart';
import '../../domain/repositories/printer_repository.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  final PosDatabase _db;

  PrinterRepositoryImpl(this._db);

  @override
  Future<List<PrinterConfigModel>> getPrintersConfig() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query('printers_config');
    return List.generate(maps.length, (i) => PrinterConfigModel.fromMap(maps[i]));
  }

  @override
  Future<PrinterConfigModel?> getPrinterConfigById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'printers_config',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PrinterConfigModel.fromMap(maps.first);
  }

  @override
  Future<PrinterConfigModel?> getPrinterConfigByType(String type) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'printers_config',
      where: 'type = ?',
      whereArgs: [type],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PrinterConfigModel.fromMap(maps.first);
  }

  @override
  Future<void> savePrinterConfig(PrinterConfigModel config) async {
    final db = await _db.database;
    await db.insert(
      'printers_config',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deletePrinterConfig(String id) async {
    final db = await _db.database;
    await db.delete(
      'printers_config',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updatePrinterConnectionStatus(String id, bool isConnected) async {
    final db = await _db.database;
    await db.update(
      'printers_config',
      {
        'is_connected': isConnected ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
