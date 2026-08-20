import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';

class PasswordRecoveryService {
  final String _baseUrl = apiBaseUrl;

  Future<void> requestOtp(String email) async {
    final url = Uri.parse('$_baseUrl/api/password/forgot');
    final response = await http.post(
      url,
      headers: getApiHeaders(),
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: apiTimeoutSeconds));

    if (response.statusCode == 429) {
      throw Exception('Terlalu banyak percobaan. Silakan tunggu 1 menit lalu coba lagi.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Gagal menghubungi server (${response.statusCode})');
    }

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Gagal meminta OTP password.');
    }
  }

  Future<String> verifyOtp(String email, String otp) async {
    final url = Uri.parse('$_baseUrl/api/password/verify-otp');
    final response = await http.post(
      url,
      headers: getApiHeaders(),
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    ).timeout(const Duration(seconds: apiTimeoutSeconds));

    if (response.statusCode == 429) {
      throw Exception('Terlalu banyak percobaan. Silakan tunggu 1 menit lalu coba lagi.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Gagal memproses respons server (${response.statusCode})');
    }

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Gagal memverifikasi OTP password.');
    }

    return data['reset_token'];
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final url = Uri.parse('$_baseUrl/api/password/reset');
    final response = await http.post(
      url,
      headers: getApiHeaders(),
      body: jsonEncode({
        'email': email,
        'reset_token': resetToken,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }),
    ).timeout(const Duration(seconds: apiTimeoutSeconds));

    if (response.statusCode == 429) {
      throw Exception('Terlalu banyak percobaan. Silakan tunggu 1 menit lalu coba lagi.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Gagal memproses respons server (${response.statusCode})');
    }

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Gagal mengatur ulang password.');
    }
  }
}
