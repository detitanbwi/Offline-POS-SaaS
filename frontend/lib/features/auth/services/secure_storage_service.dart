import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyLocalPin = 'local_pin';
  static const String _keyOnlineToken = 'online_token';
  static const String _keyOfflineToken = 'offline_token';

  Future<void> saveLocalPIN(String pin) async {
    await _storage.write(key: _keyLocalPin, value: pin);
  }

  Future<String?> getLocalPIN() async {
    return await _storage.read(key: _keyLocalPin);
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

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
