import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import '../../../../features/auth/services/secure_storage_service.dart';

/// Independent SQLite database datasource specifically for the Security Domain.
/// Adheres to Clean Architecture and Domain-Driven Design (DDD).
/// Ensuring future migrations in product/transaction tables will NEVER affect this security schema.
class SecurityDatabase {
  static final SecurityDatabase instance = SecurityDatabase._init();
  static Database? _database;

  SecurityDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_security_core.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
    
    if (isDesktop) {
      sqfliteFfiInit();
    }

    final dbPath = isDesktop 
        ? await databaseFactoryFfi.getDatabasesPath()
        : await getDatabasesPath();
    final path = join(dbPath, filePath);

    final storage = SecureStorageService();
    final encryptionKey = await storage.getEncryptionKey();

    final shouldEncrypt = !kDebugMode && Platform.isAndroid && encryptionKey != null && encryptionKey.isNotEmpty;

    if (!shouldEncrypt) {
      try {
        if (isDesktop) {
          return await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: _createDB,
              onUpgrade: _upgradeDB,
              onConfigure: _onConfigure,
            ),
          );
        } else {
          return await openDatabase(
            path,
            version: 1,
            onCreate: _createDB,
            onUpgrade: _upgradeDB,
            onConfigure: _onConfigure,
          );
        }
      } catch (e) {
        // Fallback: Delete and recreate if corrupted or previously encrypted
        if (isDesktop) {
          await databaseFactoryFfi.deleteDatabase(path);
          return await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: _createDB,
              onUpgrade: _upgradeDB,
              onConfigure: _onConfigure,
            ),
          );
        } else {
          await deleteDatabase(path);
          return await openDatabase(
            path,
            version: 1,
            onCreate: _createDB,
            onUpgrade: _upgradeDB,
            onConfigure: _onConfigure,
          );
        }
      }
    }

    Database? db;
    try {
      db = await openDatabase(
        path,
        version: 1,
        password: encryptionKey,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      // Fallback: Delete and recreate if encryption key changed or DB corrupted
      await deleteDatabase(path);
      db = await openDatabase(
        path,
        version: 1,
        password: encryptionKey,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onConfigure: _onConfigure,
      );
    }

    return db;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Database Schema & Migration Script for "License & Security" credentials.
  /// Completely isolated from transactional and product tables.
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS security_credentials (
        id TEXT PRIMARY KEY,
        master_pin_hash TEXT NOT NULL,
        recovery_code_hash TEXT NOT NULL,
        license_key_last_six TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_security_credentials_id ON security_credentials(id)',
    );
  }

  /// Handles any future migrations for the independent Security Domain without affecting products/transactions.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Future security schema evolutions go here.
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
