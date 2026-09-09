import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;
import 'package:path_provider/path_provider.dart';
import '../../auth/services/secure_storage_service.dart';
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

  /// Menyimpan data profil toko & file logo (Base64) ke dalam tabel SQLite backup
  Future<void> _backupStoreProfileToDb(Database db) async {
    try {
      final storage = SecureStorageService();
      final storeName = await storage.getStoreName() ?? '';
      final storeAddress = await storage.getStoreAddress() ?? '';
      final storePhone = await storage.getStorePhone() ?? '';
      final ownerName = await storage.getOwnerName() ?? '';
      final ownerUsername = await storage.getOwnerUsername() ?? '';
      final logoPath = await storage.getStoreLogo();

      String logoBase64 = '';
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          try {
            final logoBytes = await logoFile.readAsBytes();
            logoBase64 = base64Encode(logoBytes);
          } catch (e) {
            AppLogger.warning('Failed to encode store logo to base64 for backup: $e');
          }
        }
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS store_profile_backup (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      final entries = {
        'store_name': storeName,
        'store_address': storeAddress,
        'store_phone': storePhone,
        'owner_name': ownerName,
        'owner_username': ownerUsername,
        'store_logo_base64': logoBase64,
        'backup_timestamp': DateTime.now().toIso8601String(),
      };

      for (final entry in entries.entries) {
        await db.insert(
          'store_profile_backup',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      AppLogger.info('Store profile and logo backed up into database table successfully');
    } catch (e) {
      AppLogger.warning('Failed to backup store profile to database table: $e');
    }
  }

  /// Memulihkan data profil toko & file logo dari tabel SQLite backup ke SecureStorage & ASD
  Future<void> _restoreStoreProfileFromDb(Database db) async {
    try {
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='store_profile_backup'",
      );
      if (tableCheck.isEmpty) {
        AppLogger.info('No store_profile_backup table found in restored database');
        return;
      }

      final rows = await db.query('store_profile_backup');
      final map = <String, String>{};
      for (final r in rows) {
        final k = r['key'] as String?;
        final v = r['value'] as String?;
        if (k != null && v != null) {
          map[k] = v;
        }
      }

      final storage = SecureStorageService();
      final storeName = map['store_name'];
      final storeAddress = map['store_address'];
      final storePhone = map['store_phone'];
      final ownerName = map['owner_name'];
      final ownerUsername = map['owner_username'];
      final logoBase64 = map['store_logo_base64'];

      if (storeName != null || storeAddress != null || storePhone != null) {
        await storage.saveStoreInfo(
          name: storeName ?? '',
          address: storeAddress ?? '',
          phone: storePhone ?? '',
        );
      }
      if (ownerName != null && ownerName.isNotEmpty) {
        await storage.saveOwnerName(ownerName);
      }
      if (ownerUsername != null && ownerUsername.isNotEmpty) {
        await storage.saveOwnerUsername(ownerUsername);
      }

      if (logoBase64 != null && logoBase64.isNotEmpty) {
        try {
          final logoBytes = base64Decode(logoBase64);
          final appDir = await getApplicationSupportDirectory();
          final logosDir = Directory(join(appDir.path, 'logos'));
          if (!await logosDir.exists()) {
            await logosDir.create(recursive: true);
          }
          final restoredPath = join(logosDir.path, 'store_logo_restored_${DateTime.now().millisecondsSinceEpoch}.png');
          final logoFile = File(restoredPath);
          await logoFile.writeAsBytes(logoBytes);
          await storage.saveStoreLogo(restoredPath);
          AppLogger.info('Store logo restored to: $restoredPath');
        } catch (logoErr) {
          AppLogger.warning('Failed to decode/save restored store logo: $logoErr');
        }
      }

      AppLogger.info('Store profile restored successfully from database backup');
    } catch (e) {
      AppLogger.warning('Failed restoring store profile from database: $e');
    }
  }

  /// Memvalidasi integritas file, struktur SQLite/SQLCipher, dan kecocokan skema tabel POS sebelum di-restore
  Future<BackupValidationResult> validateBackupFile(String filePath) async {
    File? tempValidateFile;
    Database? testDb;
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

      // Salin ke file sementara di cache internal app agar aman dari lock / permission file_picker Android
      final tempDir = await getTemporaryDirectory();
      final tempPath = join(tempDir.path, 'temp_val_${DateTime.now().millisecondsSinceEpoch}.db');
      final bytes = await file.readAsBytes();
      tempValidateFile = File(tempPath);
      await tempValidateFile.writeAsBytes(bytes, flush: true);

      // Validasi Integritas SQLite & Skema Tabel Inti POS (Mendukung Standar SQLite & Terenkripsi SQLCipher)
      final storage = SecureStorageService();
      final encryptionKey = await storage.getEncryptionKey();
      final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
      
      // Strategi 1: Buka sebagai plain/unencrypted database (Standar POS)
      try {
        if (isDesktop) {
          testDb = await databaseFactoryFfi.openDatabase(
            tempPath,
            options: OpenDatabaseOptions(readOnly: false),
          );
        } else {
          testDb = await openDatabase(
            tempPath,
            readOnly: false,
          );
        }
      } catch (e1) {
        // Strategi 2: Fallback jika file cadangan versi lama masih terenkripsi SQLCipher
        if (encryptionKey != null && encryptionKey.isNotEmpty) {
          try {
            if (isDesktop) {
              testDb = await databaseFactoryFfi.openDatabase(
                tempPath,
                options: OpenDatabaseOptions(readOnly: false),
              );
            } else {
              testDb = await openDatabase(
                tempPath,
                password: encryptionKey,
                readOnly: false,
              );
            }
          } catch (e2) {
            testDb = null;
          }
        }
      }

      if (testDb == null) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Format file tidak valid atau file rusak (Bukan database SQLite POS yang sah).',
        );
      }

      // Uji integritas struktur tabel
      try {
        final integrity = await testDb.rawQuery('PRAGMA quick_check');
        if (integrity.isNotEmpty) {
          final status = integrity.first.values.first.toString().toLowerCase();
          if (status != 'ok') {
            return BackupValidationResult(
              isValid: false,
              errorMessage: 'Database tidak lolos uji integritas: $status',
            );
          }
        }
      } catch (integErr) {
        AppLogger.warning('Notice: PRAGMA quick_check skipped: $integErr');
      }

      // Periksa keberadaan tabel inti POS
      final tablesRes = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tablesRes.map((r) => r['name'] as String).toSet();

      // Validasi tabel pokok POS
      const requiredCoreTables = ['products', 'categories'];
      final missingCore = requiredCoreTables.where((t) => !tableNames.contains(t)).toList();

      if (missingCore.isNotEmpty) {
        return BackupValidationResult(
          isValid: false,
          errorMessage: 'Skema tidak cocok dengan POS (Tabel inti hilang: ${missingCore.join(", ")}).',
        );
      }

      // Pastikan ada setidaknya salah satu tabel transaksi/order
      final hasTransactionTables = tableNames.contains('orders') ||
          tableNames.contains('master_orders') ||
          tableNames.contains('transactions');
      if (!hasTransactionTables) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Skema tidak valid: Tidak ditemukan tabel pesanan atau transaksi POS.',
        );
      }

      return BackupValidationResult(isValid: true, tableCount: tableNames.length);
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'Terjadi kesalahan saat memvalidasi file: $e',
      );
    } finally {
      if (testDb != null && testDb.isOpen) {
        try {
          await testDb.close();
        } catch (_) {}
      }
      if (tempValidateFile != null && await tempValidateFile.exists()) {
        try {
          await tempValidateFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<bool> createBackup() async {
    try {
      final backupDir = await getApplicationDocumentsDirectory();
      final targetFile = File(join(backupDir.path, backupName));

      // 1. Sinkronisasi data profil toko dan logo ke dalam tabel SQLite backup
      final db = await PosDatabase.instance.database;
      await _backupStoreProfileToDb(db);

      // 2. Force SQLite to flush Write-Ahead Log (WAL) to main database file
      try {
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (walErr) {
        AppLogger.warning('Failed WAL checkpoint before backup: $walErr');
      }

      // 2. Export database cadangan unencrypted (bersih, portabel & tanpa isu kunci)
      bool exportSuccess = false;
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      final escapedPath = targetFile.path.replaceAll("'", "''");

      // Coba 1: VACUUM INTO (Menghasilkan clean SQLite snapshot)
      try {
        await db.execute("VACUUM INTO '$escapedPath'");
        exportSuccess = await targetFile.exists() && (await targetFile.length()) > 100;
        if (exportSuccess) {
          AppLogger.info('Successfully exported backup using VACUUM INTO');
        }
      } catch (vacErr) {
        AppLogger.warning('VACUUM INTO export failed, falling back to direct copy: $vacErr');
      }

      // Coba 2: Fallback ke direct copy jika VACUUM INTO gagal
      if (!exportSuccess) {
        final dbDir = await _getDbDirectory();
        final sourceFile = File(join(dbDir, dbName));

        if (!await sourceFile.exists()) {
          AppLogger.warning('POS Database source file not found for backup at: ${sourceFile.path}');
          return false;
        }

        await sourceFile.copy(targetFile.path);
      }

      // 3. Export juga salinan ke folder Downloads publik dengan format ddMMyy_timestamp_appkasirpro.db
      try {
        final now = DateTime.now();
        final datePart = DateFormat('ddMMyy').format(now);
        final timePart = DateFormat('HHmmss').format(now);
        final publicBackupName = '${datePart}_${timePart}_appkasirpro.db';
        final backupBytes = await targetFile.readAsBytes();
        final publicBackupFile = await FileSaverUtil.saveToDownloads(backupBytes, publicBackupName);
        AppLogger.info('Public backup saved to: ${publicBackupFile.path}');
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
      final walFile = File(join(dbDir, '$dbName-wal'));
      final shmFile = File(join(dbDir, '$dbName-shm'));
      final journalFile = File(join(dbDir, '$dbName-journal'));

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

      // 4. Hapus sisa-sisa file WAL/SHM/Journal lama agar tidak mereplay transaksi lama ke database baru
      try {
        if (await walFile.exists()) await walFile.delete();
        if (await shmFile.exists()) await shmFile.delete();
        if (await journalFile.exists()) await journalFile.delete();
      } catch (walErr) {
        AppLogger.warning('Notice: Cleaning old WAL files before restore: $walErr');
      }

      // 5. Salin file database cadangan baru menimpa target aktif (menggunakan byte copy untuk kompatibilitas multi-storage)
      try {
        final bytes = await selectedFile.readAsBytes();
        await targetFile.writeAsBytes(bytes, flush: true);
      } catch (_) {
        await selectedFile.copy(targetFile.path);
      }

      // 6. Uji inisialisasi dan verifikasi database yang baru disalin
      try {
        final db = await PosDatabase.instance.database;
        final prodRes = await db.rawQuery('SELECT count(*) as count FROM products WHERE is_deleted = 0');
        final catRes = await db.rawQuery('SELECT count(*) as count FROM categories WHERE is_deleted = 0');
        final prodCount = (prodRes.first['count'] as num?)?.toInt() ?? 0;
        final catCount = (catRes.first['count'] as num?)?.toInt() ?? 0;

        // 7. Pulihkan data profil toko dan logo dari tabel cadangan
        await _restoreStoreProfileFromDb(db);

        // Berhasil! Hapus file snapshot pengaman (.bak) otomatis
        if (await backupBakFile.exists()) {
          await backupBakFile.delete();
        }

        AppLogger.info('Backup restored and verified successfully from: $filePath ($prodCount produk, $catCount kategori)');
        return {
          'success': true,
          'message': 'Database dan profil toko berhasil dipulihkan ($prodCount produk aktif, $catCount kategori).',
        };
      } catch (verifyErr) {
        AppLogger.error('Restored database failed initialization verification, rolling back...', error: verifyErr);

        // Rollback otomatis: Kembalikan file database lama dari snapshot .bak
        await PosDatabase.instance.close();
        try {
          if (await walFile.exists()) await walFile.delete();
          if (await shmFile.exists()) await shmFile.delete();
          if (await journalFile.exists()) await journalFile.delete();
        } catch (_) {}

        if (await backupBakFile.exists()) {
          try {
            final bakBytes = await backupBakFile.readAsBytes();
            await targetFile.writeAsBytes(bakBytes, flush: true);
          } catch (_) {
            await backupBakFile.copy(targetFile.path);
          }
          await backupBakFile.delete();
          await PosDatabase.instance.close();
        }

        return {
          'success': false,
          'message': 'Database gagal diverifikasi oleh sistem ($verifyErr). Perubahan telah dibatalkan secara aman (Rollback).',
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
