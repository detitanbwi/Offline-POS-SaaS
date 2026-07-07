import 'dart:async';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('license_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE license_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        license_key TEXT,
        encrypted_token TEXT,
        last_transaction_time TEXT
      )
    ''');
    
    // Seed an empty row to start with
    await db.insert('license_info', {
      'license_key': '',
      'encrypted_token': '',
      'last_transaction_time': ''
    });
  }

  Future<Map<String, dynamic>?> getLicenseInfo() async {
    final db = await instance.database;
    final result = await db.query('license_info', limit: 1);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> updateLicenseInfo({
    required String licenseKey,
    required String encryptedToken,
    required String lastTransactionTime,
  }) async {
    final db = await instance.database;
    return await db.update(
      'license_info',
      {
        'license_key': licenseKey,
        'encrypted_token': encryptedToken,
        'last_transaction_time': lastTransactionTime,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<int> clearLicenseInfo() async {
    final db = await instance.database;
    return await db.update(
      'license_info',
      {
        'license_key': '',
        'encrypted_token': '',
        'last_transaction_time': '',
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
