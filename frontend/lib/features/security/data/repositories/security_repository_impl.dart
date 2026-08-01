import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../domain/entities/security_credential.dart';
import '../../domain/repositories/security_repository.dart';
import '../datasources/security_database.dart';
import '../../../../features/auth/services/secure_storage_service.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  final SecurityDatabase _database;
  final SecureStorageService _secureStorage;

  SecurityRepositoryImpl(this._database, this._secureStorage);

  String _hashSecret(String rawSecret) {
    const salt = 'OfflinePOS_SecurityDomain_Salt_2026';
    var bytes = utf8.encode(rawSecret + salt);
    var hmac = Hmac(sha256, utf8.encode(salt));
    var digest = hmac.convert(bytes);

    for (int i = 0; i < 5000; i++) {
      digest = hmac.convert(digest.bytes);
    }
    return digest.toString();
  }

  String _oldHash(String pin) {
    const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
    var bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }

  @override
  Future<void> saveSecurityCredential(SecurityCredential credential) async {
    final db = await _database.database;
    await db.insert(
      'security_credentials',
      credential.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _secureStorage.saveLocalPIN(credential.masterPinHash);
  }

  @override
  Future<SecurityCredential?> getSecurityCredential() async {
    final db = await _database.database;
    final results = await db.query(
      'security_credentials',
      where: 'id = ?',
      whereArgs: ['master_security_core'],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return SecurityCredential.fromMap(results.first);
    }
    return null;
  }

  @override
  Future<bool> validateRecoveryCode(String candidateRecoveryCode) async {
    final credential = await getSecurityCredential();
    if (credential == null) return false;
    final normalized = candidateRecoveryCode.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
    final candidateHash = _hashSecret(normalized);
    return credential.recoveryCodeHash == candidateHash;
  }

  @override
  Future<bool> validateMasterPin(String candidatePin) async {
    final candidateHash = _hashSecret(candidatePin);
    final candidateOldHash = _oldHash(candidatePin);

    final credential = await getSecurityCredential();
    if (credential != null) {
      return credential.masterPinHash == candidateHash ||
             credential.masterPinHash == candidateOldHash ||
             credential.masterPinHash == candidatePin; // in case raw hash was passed
    }

    final savedPin = await _secureStorage.getLocalPIN();
    return savedPin == candidateHash ||
           savedPin == candidateOldHash ||
           savedPin == candidatePin;
  }

  @override
  Future<void> rotateMasterPinAndRecoveryCode({
    required String newMasterPinHash,
    required String newRecoveryCodeHash,
  }) async {
    final db = await _database.database;
    final existing = await getSecurityCredential();
    final now = DateTime.now();

    final updated = existing?.copyWith(
          masterPinHash: newMasterPinHash,
          recoveryCodeHash: newRecoveryCodeHash,
          updatedAt: now,
        ) ??
        SecurityCredential(
          id: 'master_security_core',
          masterPinHash: newMasterPinHash,
          recoveryCodeHash: newRecoveryCodeHash,
          licenseKeyLastSix: '',
          createdAt: now,
          updatedAt: now,
        );

    await db.insert(
      'security_credentials',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _secureStorage.saveLocalPIN(newMasterPinHash);
  }

  @override
  Future<void> updateMasterPinHash(String newMasterPinHash) async {
    final db = await _database.database;
    final existing = await getSecurityCredential();
    final now = DateTime.now();

    if (existing != null) {
      final updated = existing.copyWith(
        masterPinHash: newMasterPinHash,
        updatedAt: now,
      );
      await db.insert(
        'security_credentials',
        updated.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      final newCred = SecurityCredential(
        id: 'master_security_core',
        masterPinHash: newMasterPinHash,
        recoveryCodeHash: '',
        licenseKeyLastSix: '',
        createdAt: now,
        updatedAt: now,
      );
      await db.insert(
        'security_credentials',
        newCred.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await _secureStorage.saveLocalPIN(newMasterPinHash);
  }

  @override
  Future<void> clearSecurityCredentials() async {
    final db = await _database.database;
    await db.delete('security_credentials');
  }
}

