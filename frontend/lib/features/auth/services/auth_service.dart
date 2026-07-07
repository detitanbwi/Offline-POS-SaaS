import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

class AuthService {
  final String baseUrl = "https://demo2.wirodev.com";
  final SecureStorageService _storage = SecureStorageService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await _storage.saveTokens(
          onlineToken: data['access_token'],
          offlineToken: await _storage.getOfflineToken() ?? '',
        );
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login Gagal'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server (Timeout/Offline)'};
    }
  }
}
