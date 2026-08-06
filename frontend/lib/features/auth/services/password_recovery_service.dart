import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';

class PasswordRecoveryService {
  final String _baseUrl = apiBaseUrl;

  Future<void> requestOtp(String email) async {
    final url = Uri.parse('$_baseUrl/api/password/forgot');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Gagal meminta OTP password.');
    }
  }

  Future<String> verifyOtp(String email, String otp) async {
    final url = Uri.parse('$_baseUrl/api/password/verify-otp');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    );

    final data = jsonDecode(response.body);
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
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email,
        'reset_token': resetToken,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Gagal mengatur ulang password.');
    }
  }
}
