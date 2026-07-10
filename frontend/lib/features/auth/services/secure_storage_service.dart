import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  static const String _keyStoreName = 'store_name';
  static const String _keyStoreAddress = 'store_address';
  static const String _keyStorePhone = 'store_phone';

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
  }

  Future<String?> getStoreName() async {
    return await _storage.read(key: _keyStoreName);
  }

  Future<String?> getStoreAddress() async {
    return await _storage.read(key: _keyStoreAddress);
  }

  Future<String?> getStorePhone() async {
    return await _storage.read(key: _keyStorePhone);
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

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
