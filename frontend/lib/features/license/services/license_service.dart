import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/services/secure_storage_service.dart';
import '../../../core/services/device_fingerprint_service.dart';
import '../../../core/constants/app_constants.dart';

class LicenseService {
  final SecureStorageService _storage;
  final DeviceFingerprintService _fingerprintService;

  LicenseService(this._storage, this._fingerprintService);

  Future<Map<String, dynamic>> activate(String licenseKey) async {
    try {
      final onlineToken = await _storage.getOnlineToken();
      if (onlineToken == null || onlineToken.isEmpty) {
        return {'success': false, 'message': 'Token online tidak ditemukan. Silakan login kembali.'};
      }

      final timestamp = DateTime.now().toIso8601String();
      final fingerprint = await _fingerprintService.generateFingerprint(timestamp);
      final deviceInfo = await _fingerprintService.getDeviceInfo();

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/activate'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $onlineToken',
        },
        body: jsonEncode({
          'token_key': licenseKey,
          'license_key': licenseKey,
          'fingerprint_hash': fingerprint,
          'device_name': deviceInfo['device_name'],
          'manufacturer': deviceInfo['manufacturer'],
          'brand': deviceInfo['device_brand'],
          'model': deviceInfo['device_model'],
        }),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final offlineToken = data['offline_token'] ?? '';
        final rawKeyString = '$licenseKey$fingerprint$offlineToken';
        final keyBytes = utf8.encode(rawKeyString);
        final dbEncryptionKey = sha256.convert(keyBytes).toString();

        await _storage.saveActivationData(
          activationToken: data['offline_token'],
          licenseKey: licenseKey,
          encryptionKey: dbEncryptionKey,
          fingerprintHash: fingerprint,
          expiryDateStr: data['expires_at'],
        );

        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Aktivasi gagal'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal menghubungi server lisensi (Offline)'};
    }
  }

  Future<Map<String, dynamic>> validateLicenseOnline({int? customTimeout}) async {
    try {
      final onlineToken = await _storage.getOnlineToken();
      final licenseKey = await _storage.getLicenseKey();
      final fingerprint = await _storage.getFingerprintHash();

      if (onlineToken == null || licenseKey == null || fingerprint == null) {
        return {'success': false, 'message': 'Data aktivasi tidak lengkap'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/validate-license'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $onlineToken',
        },
        body: jsonEncode({
          'token_key': licenseKey,
          'license_key': licenseKey,
          'fingerprint_hash': fingerprint,
        }),
      ).timeout(Duration(seconds: customTimeout ?? apiTimeoutSeconds));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await _storage.saveLastValidation(DateTime.now().toIso8601String());
        if (data['expires_at'] != null) {
          const secureStorage = FlutterSecureStorage();
          await secureStorage.write(key: 'license_expiry', value: data['expires_at']);
        }
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Validasi gagal'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi internet tidak tersedia', 'is_offline': true};
    }
  }

  Future<Map<String, dynamic>> getLicenseInfo() async {
    try {
      final onlineToken = await _storage.getOnlineToken();
      if (onlineToken == null || onlineToken.isEmpty) {
        return {'success': false, 'message': 'Token login tidak ditemukan'};
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/license-info'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $onlineToken',
        },
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (data['tenant'] != null) {
          final tenant = data['tenant'];
          await _storage.saveStoreInfo(
            name: tenant['store_name'] ?? tenant['name'] ?? '',
            address: tenant['store_address'] ?? '',
            phone: tenant['phone'] ?? '',
          );
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal mengambil informasi lisensi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  Future<bool> checkLicenseOffline() async {
    final expiryStr = await _storage.getLicenseExpiry();
    if (expiryStr == null || expiryStr.isEmpty) return false;

    try {
      final expiryDate = DateTime.parse(expiryStr);
      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }
}
