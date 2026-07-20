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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      final data = jsonDecode(response.body);

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
        return {'success': false, 'message': data['message'] ?? 'Login Gagal'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server (Timeout/Offline)'};
    }
  }
}
