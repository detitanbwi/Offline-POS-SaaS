import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../security/data/datasources/security_database.dart';
import '../../../../core/database/pos_database.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyLocalPin = 'local_pin';
  static const String _keyOnlineToken = 'online_token';
  static const String _keyOfflineToken = 'offline_token';
  
  static const String _keyActivationToken = 'activation_token';
  static const String _keyLicenseKey = 'license_key';
  static const String _keyEncryptionKey = 'db_encryption_key';
  static const String _keyLastValidation = 'last_validation_time';
  static const String _keyLicenseExpiry = 'license_expiry';
  static const String _keyFingerprintHash = 'fingerprint_hash';
  static const String _keyPublicKey = 'public_key';

  static const String _keyStoreName = 'store_name';
  static const String _keyStoreAddress = 'store_address';
  static const String _keyStorePhone = 'store_phone';
  static const String _keyStoreLogo = 'store_logo_path';
  static const String _keyOwnerUsername = 'owner_username';
  static const String _keyOwnerName = 'owner_name';

  Future<void> saveLocalPIN(String pin) async {
    await _storage.write(key: _keyLocalPin, value: pin);
  }

  Future<String?> getLocalPIN() async {
    return await _storage.read(key: _keyLocalPin);
  }

  Future<void> saveStoreInfo({
    required String name,
    required String address,
    required String phone,
  }) async {
    await _storage.write(key: _keyStoreName, value: name);
    await _storage.write(key: _keyStoreAddress, value: address);
    await _storage.write(key: _keyStorePhone, value: phone);

    try {
      final db = await PosDatabase.instance.database;
      await db.insert('store_profile_backup', {'key': 'store_name', 'value': name}, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('store_profile_backup', {'key': 'store_address', 'value': address}, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('store_profile_backup', {'key': 'store_phone', 'value': phone}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<String?> getStoreName() async {
    final val = await _storage.read(key: _keyStoreName);
    if (val != null && val.trim().isNotEmpty) return val;
    try {
      final db = await PosDatabase.instance.database;
      final rows = await db.query('store_profile_backup', where: 'key = ?', whereArgs: ['store_name']);
      if (rows.isNotEmpty) {
        final dbVal = rows.first['value'] as String?;
        if (dbVal != null && dbVal.trim().isNotEmpty) {
          await _storage.write(key: _keyStoreName, value: dbVal);
          return dbVal;
        }
      }
    } catch (_) {}
    return val;
  }

  Future<String?> getStoreAddress() async {
    final val = await _storage.read(key: _keyStoreAddress);
    if (val != null && val.trim().isNotEmpty) return val;
    try {
      final db = await PosDatabase.instance.database;
      final rows = await db.query('store_profile_backup', where: 'key = ?', whereArgs: ['store_address']);
      if (rows.isNotEmpty) {
        final dbVal = rows.first['value'] as String?;
        if (dbVal != null) {
          await _storage.write(key: _keyStoreAddress, value: dbVal);
          return dbVal;
        }
      }
    } catch (_) {}
    return val;
  }

  Future<String?> getStorePhone() async {
    final val = await _storage.read(key: _keyStorePhone);
    if (val != null && val.trim().isNotEmpty) return val;
    try {
      final db = await PosDatabase.instance.database;
      final rows = await db.query('store_profile_backup', where: 'key = ?', whereArgs: ['store_phone']);
      if (rows.isNotEmpty) {
        final dbVal = rows.first['value'] as String?;
        if (dbVal != null) {
          await _storage.write(key: _keyStorePhone, value: dbVal);
          return dbVal;
        }
      }
    } catch (_) {}
    return val;
  }

  Future<void> saveStoreLogo(String logoPath) async {
    await _storage.write(key: _keyStoreLogo, value: logoPath);
    try {
      final file = File(logoPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final base64 = base64Encode(bytes);
        final db = await PosDatabase.instance.database;
        await db.insert('store_profile_backup', {'key': 'store_logo_base64', 'value': base64}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {}
  }

  Future<String?> getStoreLogo() async {
    final path = await _storage.read(key: _keyStoreLogo);
    if (path != null && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  Future<void> deleteStoreLogo() async {
    await _storage.delete(key: _keyStoreLogo);
    try {
      final db = await PosDatabase.instance.database;
      await db.insert('store_profile_backup', {'key': 'store_logo_base64', 'value': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> saveOwnerUsername(String username) async {
    await _storage.write(key: _keyOwnerUsername, value: username.trim());
    try {
      final db = await PosDatabase.instance.database;
      await db.insert('store_profile_backup', {'key': 'owner_username', 'value': username.trim()}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<String?> getOwnerUsername() async {
    final username = await _storage.read(key: _keyOwnerUsername);
    if (username == null || username.trim().isEmpty) {
      return 'owner';
    }
    return username.trim();
  }

  Future<void> saveOwnerName(String name) async {
    await _storage.write(key: _keyOwnerName, value: name.trim());
    try {
      final db = await PosDatabase.instance.database;
      await db.insert('store_profile_backup', {'key': 'owner_name', 'value': name.trim()}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<String?> getOwnerName() async {
    final val = await _storage.read(key: _keyOwnerName);
    if (val != null) return val.trim();
    try {
      final db = await PosDatabase.instance.database;
      final rows = await db.query('store_profile_backup', where: 'key = ?', whereArgs: ['owner_name']);
      if (rows.isNotEmpty) {
        final dbVal = rows.first['value'] as String?;
        if (dbVal != null) {
          await _storage.write(key: _keyOwnerName, value: dbVal.trim());
          return dbVal.trim();
        }
      }
    } catch (_) {}
    return null;
  }



  Future<void> saveTokens({required String onlineToken, required String offlineToken}) async {
    await _storage.write(key: _keyOnlineToken, value: onlineToken);
    await _storage.write(key: _keyOfflineToken, value: offlineToken);
  }

  Future<String?> getOnlineToken() async {
    return await _storage.read(key: _keyOnlineToken);
  }

  Future<String?> getOfflineToken() async {
    return await _storage.read(key: _keyOfflineToken);
  }

  // SaaS activation methods
  Future<void> saveActivationData({
    required String activationToken,
    required String licenseKey,
    required String encryptionKey,
    required String fingerprintHash,
    required String expiryDateStr,
  }) async {
    await _storage.write(key: _keyActivationToken, value: activationToken);
    await _storage.write(key: _keyLicenseKey, value: licenseKey);
    await _storage.write(key: _keyEncryptionKey, value: encryptionKey);
    await _storage.write(key: _keyFingerprintHash, value: fingerprintHash);
    await _storage.write(key: _keyLicenseExpiry, value: expiryDateStr);
    await _storage.write(key: _keyLastValidation, value: DateTime.now().toIso8601String());
  }

  Future<String?> getActivationToken() async {
    return await _storage.read(key: _keyActivationToken);
  }

  Future<String?> getLicenseKey() async {
    return await _storage.read(key: _keyLicenseKey);
  }

  Future<String?> getEncryptionKey() async {
    return await _storage.read(key: _keyEncryptionKey);
  }

  Future<String?> getFingerprintHash() async {
    return await _storage.read(key: _keyFingerprintHash);
  }

  Future<String?> getLicenseExpiry() async {
    return await _storage.read(key: _keyLicenseExpiry);
  }

  Future<String?> getLastValidation() async {
    return await _storage.read(key: _keyLastValidation);
  }

  Future<void> saveLastValidation(String timeStr) async {
    await _storage.write(key: _keyLastValidation, value: timeStr);
  }

  Future<void> savePublicKey(String publicKey) async {
    await _storage.write(key: _keyPublicKey, value: publicKey);
  }

  Future<String?> getPublicKey() async {
    return await _storage.read(key: _keyPublicKey);
  }

  /// Menghapus sesi autentikasi online (Logout) tanpa merusak database offline & lisensi
  Future<void> clearAuthSession() async {
    await _storage.delete(key: _keyOnlineToken);
  }

  /// Menghapus semua data key-value di secure storage tanpa menghapus file database SQLite
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Menghapus seluruh data lokal & file database SQLite (Factory Reset / Wipe Data)
  Future<void> wipeAllData() async {
    await _storage.deleteAll();
    try {
      await SecurityDatabase.instance.deleteDatabaseFile();
    } catch (_) {}
    try {
      await PosDatabase.instance.deleteDatabaseFile();
    } catch (_) {}
  }
}

