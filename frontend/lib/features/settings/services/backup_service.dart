import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/services/app_logger.dart';

class BackupService {
  static const String dbName = 'pos_database.db';
  static const String backupName = 'pos_database_backup.db';

  Future<String> _getDbDirectory() async {
    final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
    if (isDesktop) {
      return await databaseFactoryFfi.getDatabasesPath();
    }
    return await getDatabasesPath();
  }

  Future<bool> createBackup() async {
    try {
      // 1. Force SQLite to flush Write-Ahead Log (WAL) to main database file
      try {
        final db = await PosDatabase.instance.database;
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (walErr) {
        AppLogger.warning('Failed WAL checkpoint before backup: $walErr');
      }

      final dbDir = await _getDbDirectory();
      final sourceFile = File(join(dbDir, dbName));

      if (!await sourceFile.exists()) {
        AppLogger.warning('POS Database source file not found for backup at: ${sourceFile.path}');
        return false;
      }

      final backupDir = await getApplicationDocumentsDirectory();
      final targetFile = File(join(backupDir.path, backupName));

      // Copy database file
      await sourceFile.copy(targetFile.path);
      AppLogger.info('Backup created successfully at: ${targetFile.path}');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create database backup', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> restoreBackup() async {
    try {
      final backupDir = await getApplicationDocumentsDirectory();
      final backupFile = File(join(backupDir.path, backupName));

      if (!await backupFile.exists()) {
        AppLogger.warning('No backup file found at: ${backupFile.path}');
        return false;
      }

      final dbDir = await _getDbDirectory();
      final targetFile = File(join(dbDir, dbName));

      // 1. Close current active database connection cleanly before rewriting file
      await PosDatabase.instance.close();

      // 2. Copy backup file over main DB file
      await backupFile.copy(targetFile.path);

      // 3. Reset database instance again to force clean re-open on next query
      await PosDatabase.instance.close();

      AppLogger.info('Backup restored successfully from: ${backupFile.path}');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to restore database backup', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> hasBackup() async {
    try {
      final backupDir = await getApplicationDocumentsDirectory();
      final backupFile = File(join(backupDir.path, backupName));
      return await backupFile.exists();
    } catch (e) {
      return false;
    }
  }

  Future<String?> getBackupDetails() async {
    try {
      final backupDir = await getApplicationDocumentsDirectory();
      final backupFile = File(join(backupDir.path, backupName));
      if (await backupFile.exists()) {
        final stat = await backupFile.stat();
        final sizeKb = (stat.size / 1024).toStringAsFixed(1);
        final lastModified = stat.modified.toLocal().toString().split('.').first;
        return 'Size: $sizeKb KB, Modified: $lastModified';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
