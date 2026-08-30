import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
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

      // timestamp variable removed since we no longer pass it to generateFingerprint
      final fingerprint = await _fingerprintService.generateFingerprint();
      final deviceInfo = await _fingerprintService.getDeviceInfo();

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/activate'),
        headers: getApiHeaders(bearerToken: onlineToken),
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

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        return {'success': false, 'message': 'Gagal memproses respons server (${response.statusCode})'};
      }

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

        // Fetch Public Key
        try {
          final pkResponse = await http.get(
            Uri.parse('$apiBaseUrl/api/license-public-key'),
            headers: getApiHeaders(bearerToken: onlineToken),
          ).timeout(const Duration(seconds: apiTimeoutSeconds));
          if (pkResponse.statusCode == 200) {
            final pkData = jsonDecode(pkResponse.body);
            if (pkData['success'] == true && pkData['public_key'] != null) {
              await _storage.savePublicKey(pkData['public_key']);
            }
          }
        } catch (_) {}

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
        headers: getApiHeaders(bearerToken: onlineToken),
        body: jsonEncode({
          'token_key': licenseKey,
          'license_key': licenseKey,
          'fingerprint_hash': fingerprint,
        }),
      ).timeout(Duration(seconds: customTimeout ?? apiTimeoutSeconds));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        return {'success': false, 'message': 'Gagal memproses respons server (${response.statusCode})'};
      }

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
        headers: getApiHeaders(bearerToken: onlineToken),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        return {'success': false, 'message': 'Gagal memproses respons server (${response.statusCode})'};
      }
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
    final activationToken = await _storage.getActivationToken();
    final publicKeyPem = await _storage.getPublicKey();
    
    if (activationToken == null || activationToken.isEmpty) return false;

    final lastValidationStr = await _storage.getLastValidation();

    try {
      if (lastValidationStr != null && lastValidationStr.isNotEmpty) {
        final lastValidation = DateTime.parse(lastValidationStr);
        if (DateTime.now().isBefore(lastValidation)) {
          return false; // Indikasi manipulasi waktu (dimundurkan)
        }
      }

      DateTime? expiryDate;
      
      // Verifikasi dengan JWT Public Key jika tersedia
      if (publicKeyPem != null && publicKeyPem.isNotEmpty) {
        try {
          final publicKey = RSAPublicKey(publicKeyPem);
          final jwt = JWT.verify(activationToken, publicKey);
          if (jwt.payload['exp'] != null) {
             // JWT exp is in seconds
             expiryDate = DateTime.fromMillisecondsSinceEpoch((jwt.payload['exp'] as int) * 1000);
          }
        } catch (e) {
          // Signature tidak valid atau token ditamper
          return false;
        }
      }

      // Fallback (untuk kompatibilitas jika token format lama / belum terunduh public key)
      if (expiryDate == null) {
         final expiryStr = await _storage.getLicenseExpiry();
         if (expiryStr == null || expiryStr.isEmpty) return false;
         expiryDate = DateTime.parse(expiryStr);
      }

      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }
}
