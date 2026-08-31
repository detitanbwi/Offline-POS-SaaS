import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/file_saver_util.dart';

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? tableCount;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.tableCount,
  });
}

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

  /// Memvalidasi integritas file, header SQLite, dan kecocokan skema tabel POS sebelum di-restore
  Future<BackupValidationResult> validateBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'File cadangan tidak ditemukan di penyimpanan.',
        );
      }

      final length = await file.length();
      if (length < 100) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'File cadangan kosong atau rusak (ukuran terlalu kecil).',
        );
      }

      // 1. Validasi Magic Header SQLite (16 byte pertama: "SQLite format 3\0")
      final headerStream = file.openRead(0, 16);
      final headerBytes = await headerStream.first;
      final headerString = String.fromCharCodes(headerBytes);
      if (!headerString.startsWith('SQLite format 3')) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Format file tidak valid. File bukan database SQLite yang sah.',
        );
      }

      // 2. Validasi Integritas SQLite & Skema Tabel Inti POS
      final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
      Database? testDb;
      try {
        if (isDesktop) {
          testDb = await databaseFactoryFfi.openDatabase(
            filePath,
            options: OpenDatabaseOptions(readOnly: true),
          );
        } else {
          testDb = await openReadOnlyDatabase(filePath);
        }

        // Uji integritas struktur tabel
        final integrity = await testDb.rawQuery('PRAGMA quick_check');
        if (integrity.isNotEmpty) {
          final status = integrity.first.values.first.toString().toLowerCase();
          if (status != 'ok') {
            await testDb.close();
            return BackupValidationResult(
              isValid: false,
              errorMessage: 'Database tidak lolos uji integritas: $status',
            );
          }
        }

        // Periksa keberadaan tabel inti POS
        final tablesRes = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tablesRes.map((r) => r['name'] as String).toSet();

        const requiredTables = ['products', 'categories', 'master_orders', 'cashiers'];
        final missingTables = requiredTables.where((t) => !tableNames.contains(t)).toList();

        if (missingTables.isNotEmpty) {
          await testDb.close();
          return BackupValidationResult(
            isValid: false,
            errorMessage: 'Skema tidak cocok dengan POS (Tabel hilang: ${missingTables.join(", ")}).',
          );
        }

        await testDb.close();
        return BackupValidationResult(isValid: true, tableCount: tableNames.length);
      } catch (dbErr) {
        try {
          await testDb?.close();
        } catch (_) {}
        return BackupValidationResult(
          isValid: false,
          errorMessage: 'Gagal membaca skema database: $dbErr',
        );
      }
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'Terjadi kesalahan saat memvalidasi file: $e',
      );
    }
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
        if (!kIsWeb && Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            await Permission.manageExternalStorage.request();
          }
        }

        final downloadsDir = await FileSaverUtil.getDownloadsDirectoryPath();
        final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').replaceFirst('T', '_');
        final publicBackupName = 'pos_database_backup_$timestamp.db';
        final publicBackupFile = File(join(downloadsDir.path, publicBackupName));
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

  Future<Map<String, dynamic>> restoreFromPath(String filePath) async {
    try {
      // 1. Validasi file, header SQLite, dan struktur tabel POS
      final validation = await validateBackupFile(filePath);
      if (!validation.isValid) {
        return {
          'success': false,
          'message': validation.errorMessage ?? 'File cadangan tidak valid.',
        };
      }

      final selectedFile = File(filePath);
      final dbDir = await _getDbDirectory();
      final targetFile = File(join(dbDir, dbName));
      final backupBakFile = File(join(dbDir, '$dbName.bak'));

      // 2. Tutup koneksi aktif database secara aman
      await PosDatabase.instance.close();

      // 3. Buat Snapshot Pengaman (.bak) dari database yang sedang berjalan
      if (await targetFile.exists()) {
        try {
          if (await backupBakFile.exists()) {
            await backupBakFile.delete();
          }
          await targetFile.copy(backupBakFile.path);
          AppLogger.info('Created safety snapshot before restore: ${backupBakFile.path}');
        } catch (bakErr) {
          AppLogger.warning('Failed creating safety snapshot: $bakErr');
        }
      }

      // 4. Salin file database cadangan baru menimpa target aktif
      await selectedFile.copy(targetFile.path);

      // 5. Uji inisialisasi dan verifikasi database yang baru disalin
      try {
        final db = await PosDatabase.instance.database;
        await db.rawQuery('SELECT count(*) FROM products');

        // Berhasil! Hapus file snapshot pengaman (.bak) otomatis
        if (await backupBakFile.exists()) {
          await backupBakFile.delete();
        }

        AppLogger.info('Backup restored and verified successfully from: $filePath');
        return {
          'success': true,
          'message': 'Database berhasil dipulihkan dan diverifikasi.',
        };
      } catch (verifyErr) {
        AppLogger.error('Restored database failed initialization verification, rolling back...', error: verifyErr);

        // Rollback otomatis: Kembalikan file database lama dari snapshot .bak
        await PosDatabase.instance.close();
        if (await backupBakFile.exists()) {
          await backupBakFile.copy(targetFile.path);
          await backupBakFile.delete();
          await PosDatabase.instance.close();
        }

        return {
          'success': false,
          'message': 'Database gagal diverifikasi oleh sistem. Perubahan telah dibatalkan secara aman (Rollback).',
        };
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to restore database from custom path', error: e, stackTrace: stackTrace);
      return {
        'success': false,
        'message': 'Terjadi kesalahan sistem saat memulihkan database: $e',
      };
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

      final result = await restoreFromPath(backupFile.path);
      return result['success'] == true;
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
