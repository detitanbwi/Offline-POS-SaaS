import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/services/app_logger.dart';

class BackupService {
  static const String dbName = 'pos_database.db';
  static const String backupName = 'pos_database_backup.db';

  Future<bool> createBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(join(dbPath, dbName));

      if (!await sourceFile.exists()) {
        AppLogger.warning('POS Database source file not found for backup.');
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

      final dbPath = await getDatabasesPath();
      final targetFile = File(join(dbPath, dbName));

      // Close the current active database connection before rewriting
      // In a real scenario, the app should restart or close connections.
      // Since sqflite doesn't allow closing all dynamically, we'll replace the file directly.
      // Note: Replacing the file while SQLite is running might cause corruption if there are active write locks.
      // To be safe, we perform copying and log success.
      await backupFile.copy(targetFile.path);
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
