import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/services/secure_storage_service.dart';
import '../../../core/services/device_fingerprint_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/pos_database.dart';
import 'package:uuid/uuid.dart';

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

        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Aktivasi gagal'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal menghubungi server lisensi (Offline)'};
    }
  }

  Future<Map<String, dynamic>> validateLicenseOnline({int? customTimeout, String triggerType = 'Manual Refresh'}) async {
    bool isOffline = false;
    String status = 'failed';
    try {
      final onlineToken = await _storage.getOnlineToken();
      final licenseKey = await _storage.getLicenseKey();
      final fingerprint = await _storage.getFingerprintHash();

      if (onlineToken == null || licenseKey == null || fingerprint == null) {
        await _logLicenseCheck('failed', triggerType);
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
        await _logLicenseCheck('failed', triggerType);
        return {'success': false, 'message': 'Gagal memproses respons server (${response.statusCode})'};
      }

      if (response.statusCode == 200 && data['success'] == true) {
        status = 'success';
        await _storage.saveLastValidation(DateTime.now().toIso8601String());
        if (data['expires_at'] != null) {
          const secureStorage = FlutterSecureStorage();
          await secureStorage.write(key: 'license_expiry', value: data['expires_at']);
        }
        await _logLicenseCheck(status, triggerType);
        
        // Sync local logs to backend on successful check
        syncLicenseLogs();
        
        return {'success': true};
      } else {
        await _logLicenseCheck('failed', triggerType);
        return {'success': false, 'message': data['message'] ?? 'Validasi gagal'};
      }
    } catch (e) {
      isOffline = true;
      await _logLicenseCheck('offline', triggerType);
      return {'success': false, 'message': 'Koneksi internet tidak tersedia', 'is_offline': true};
    }
  }

  Future<Map<String, dynamic>?> performPeriodicCheck() async {
    const secureStorage = FlutterSecureStorage();
    final lastValidationStr = await secureStorage.read(key: 'last_validation_time');
    
    bool shouldCheck = true;
    if (lastValidationStr != null) {
      try {
        final lastValidation = DateTime.parse(lastValidationStr);
        if (DateTime.now().difference(lastValidation).inHours < 12) {
          shouldCheck = false;
        }
      } catch (_) {}
    }

    if (shouldCheck) {
      return await validateLicenseOnline(triggerType: 'Automatic 12-Hour Check');
    }
    return null;
  }

  Future<void> _logLicenseCheck(String status, String triggerType) async {
    try {
      final expiryStr = await _storage.getLicenseExpiry();
      int remainingSeconds = 0;
      if (expiryStr != null && expiryStr.isNotEmpty) {
        try {
          final expiryDate = DateTime.parse(expiryStr);
          remainingSeconds = expiryDate.difference(DateTime.now()).inSeconds;
          if (remainingSeconds < 0) remainingSeconds = 0;
        } catch (_) {}
      }

      final db = await PosDatabase.instance.database;
      final logId = const Uuid().v4();
      
      await db.insert('license_logs', {
        'id': logId,
        'status': status,
        'trigger_type': triggerType,
        'remaining_time_seconds': remainingSeconds,
        'is_synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Ignore if logging fails
    }
  }

  Future<void> syncLicenseLogs() async {
    try {
      final db = await PosDatabase.instance.database;
      final unsyncedLogs = await db.query('license_logs', where: 'is_synced = ?', whereArgs: [0]);
      
      if (unsyncedLogs.isEmpty) return;

      final onlineToken = await _storage.getOnlineToken();
      final licenseKey = await _storage.getLicenseKey();
      if (onlineToken == null || licenseKey == null) return;

      final logsData = unsyncedLogs.map((log) => {
        'token_key': licenseKey,
        'status': log['status'],
        'trigger_type': log['trigger_type'],
        'remaining_time_seconds': log['remaining_time_seconds'],
        'created_at': log['created_at'],
      }).toList();

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/license-logs/sync'),
        headers: getApiHeaders(bearerToken: onlineToken),
        body: jsonEncode({'logs': logsData}),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Mark as synced
          for (var log in unsyncedLogs) {
            await db.update(
              'license_logs',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [log['id']],
            );
          }
        }
      }
    } catch (_) {
      // Ignore sync failure
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
      final expiryStr = await _storage.getLicenseExpiry();
      if (expiryStr == null || expiryStr.isEmpty) return false;

      try {
        final expiryDate = DateTime.parse(expiryStr);
        return DateTime.now().isBefore(expiryDate);
      } catch (e) {
        return false;
      }
    }

    Future<Map<String, dynamic>> requestDeviceResetOtp({
      required String email,
      required String password,
      required String tokenKey,
    }) async {
      try {
        final onlineToken = await _storage.getOnlineToken();
        if (onlineToken == null || onlineToken.isEmpty) {
          return {'success': false, 'message': 'Token login tidak ditemukan'};
        }

        final response = await http.post(
          Uri.parse('$apiBaseUrl/api/auth/request-device-reset-otp'),
          headers: getApiHeaders(bearerToken: onlineToken),
          body: jsonEncode({
            'email': email,
            'password': password,
            'token_key': tokenKey,
          }),
        ).timeout(const Duration(seconds: apiTimeoutSeconds));

        Map<String, dynamic> data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          return {'success': false, 'message': 'Gagal memproses respons server (${response.statusCode})'};
        }
        return {
          'success': response.statusCode == 200 && data['success'] == true,
          'message': data['message'] ?? 'Permintaan OTP gagal',
        };
      } catch (e) {
        return {'success': false, 'message': 'Gagal terhubung ke server'};
      }
    }

    Future<Map<String, dynamic>> verifyDeviceResetOtp({
      required String email,
      required String tokenKey,
      required String otp,
    }) async {
      try {
        final onlineToken = await _storage.getOnlineToken();
        if (onlineToken == null || onlineToken.isEmpty) {
          return {'success': false, 'message': 'Token login tidak ditemukan'};
        }

        final response = await http.post(
          Uri.parse('$apiBaseUrl/api/auth/verify-device-reset-otp'),
          headers: getApiHeaders(bearerToken: onlineToken),
          body: jsonEncode({
            'email': email,
            'token_key': tokenKey,
            'otp': otp,
          }),
        ).timeout(const Duration(seconds: apiTimeoutSeconds));

        Map<String, dynamic> data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          return {'success': false, 'message': 'Gagal memproses respons server (${response.statusCode})'};
        }
        return {
          'success': response.statusCode == 200 && data['success'] == true,
          'message': data['message'] ?? 'Verifikasi OTP gagal',
        };
      } catch (e) {
        return {'success': false, 'message': 'Gagal terhubung ke server'};
      }
    }
}
