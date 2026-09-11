import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import 'secure_storage_service.dart';

class AuthService {
  final SecureStorageService _storage;

  AuthService(this._storage);

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/login'),
        headers: getApiHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      if (response.statusCode == 429) {
        return {
          'success': false,
          'message': 'Terlalu banyak percobaan login. Harap tunggu 1 menit lalu coba lagi.',
        };
      }

      if (response.statusCode == 403 &&
          (response.body.contains('Imunify360') || response.body.contains('bot-protection'))) {
        return {
          'success': false,
          'message': 'Koneksi diblokir sementara oleh proteksi server (Imunify360). Silakan coba beberapa saat lagi.',
        };
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'message': 'Gagal memproses respons server (${response.statusCode})',
        };
      }

      if (response.statusCode == 200 && data['success'] == true) {
        await _storage.saveTokens(
          onlineToken: data['access_token'],
          offlineToken: await _storage.getOfflineToken() ?? '',
        );
        if (data['tenant'] != null) {
          final tenant = data['tenant'];
          await _storage.saveStoreInfo(
            name: tenant['store_name'] ?? tenant['name'] ?? '',
            address: tenant['store_address'] ?? '',
            phone: tenant['phone'] ?? '',
          );
        }
        if (data['user'] != null && data['user']['name'] != null) {
          await _storage.saveOwnerUsername(data['user']['name']);
        }
        return {
          'success': true,
          'license_tokens': data['license_tokens'] ?? [],
        };
      } else {
        String errorMsg = data['message'] ?? 'Login Gagal';
        if (data['errors'] != null && data['errors'] is Map) {
          final errorsMap = data['errors'] as Map<String, dynamic>;
          if (errorsMap.isNotEmpty) {
            final firstVal = errorsMap.values.first;
            if (firstVal is List && firstVal.isNotEmpty) {
              errorMsg = firstVal.first.toString();
            }
          }
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server. Periksa koneksi internet Anda.'};
    }
  }
}
