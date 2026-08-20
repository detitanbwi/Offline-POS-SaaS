import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/file_saver_util.dart';

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
      final backupDir = await getApplicationDocumentsDirectory();
      final targetFile = File(join(backupDir.path, backupName));

      // 1. Force SQLite to flush Write-Ahead Log (WAL) to main database file
      final db = await PosDatabase.instance.database;
      try {
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (walErr) {
        AppLogger.warning('Failed WAL checkpoint before backup: $walErr');
      }

      // 2. Export clean unencrypted database file using SQLite VACUUM INTO
      bool vacuumSuccess = false;
      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        final escapedPath = targetFile.path.replaceAll("'", "''");
        await db.execute("VACUUM INTO '$escapedPath'");
        vacuumSuccess = await targetFile.exists();
      } catch (vacErr) {
        AppLogger.warning('VACUUM INTO export failed, falling back to direct copy: $vacErr');
      }

      // 3. Fallback to direct file copy if VACUUM INTO fails
      if (!vacuumSuccess) {
        final dbDir = await _getDbDirectory();
        final sourceFile = File(join(dbDir, dbName));

        if (!await sourceFile.exists()) {
          AppLogger.warning('POS Database source file not found for backup at: ${sourceFile.path}');
          return false;
        }

        await sourceFile.copy(targetFile.path);
      }

      // 4. Also export copy to public Downloads folder for cross-app/cross-build accessibility
      try {
        final downloadsDir = await FileSaverUtil.getDownloadsDirectoryPath();
        final publicBackupFile = File(join(downloadsDir.path, backupName));
        await targetFile.copy(publicBackupFile.path);
        AppLogger.info('Public backup copied to Downloads: ${publicBackupFile.path}');
      } catch (pubErr) {
        AppLogger.warning('Could not write backup to public Downloads folder: $pubErr');
      }

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
      File backupFile = File(join(backupDir.path, backupName));

      // Fallback: check public Downloads folder if local internal backup missing or outdated
      if (!await backupFile.exists()) {
        final downloadsDir = await FileSaverUtil.getDownloadsDirectoryPath();
        final publicFile = File(join(downloadsDir.path, backupName));
        if (await publicFile.exists()) {
          backupFile = publicFile;
        }
      }

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
