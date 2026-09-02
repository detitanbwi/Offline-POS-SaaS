import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';

class PinRecoveryException implements Exception {
  final String message;
  PinRecoveryException(this.message);

  @override
  String toString() => message;
}

class PinRecoveryService {
  final http.Client _client;

  PinRecoveryService({http.Client? client}) : _client = client ?? http.Client();

  /// 1. Request OTP ke email
  Future<void> requestOtp(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiBaseUrl/api/auth/request-otp'),
        headers: getApiHeaders(),
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      if (response.statusCode == 429) {
        throw PinRecoveryException('Terlalu banyak percobaan. Silakan tunggu 1 menit lalu coba lagi.');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw PinRecoveryException('Gagal memproses respons server (${response.statusCode})');
      }

      if (response.statusCode != 200 || data['success'] != true) {
        throw PinRecoveryException(
          data['message'] ?? 'Gagal mengirim kode OTP ke email.',
        );
      }
    } catch (e) {
      if (e is PinRecoveryException) rethrow;
      throw PinRecoveryException(
        'Gagal terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  /// 2. Verifikasi 6 digit OTP
  /// Mengembalikan `reset_token` jika valid
  Future<String> verifyOtp(String email, String otp) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiBaseUrl/api/auth/verify-otp'),
        headers: getApiHeaders(),
        body: jsonEncode({'email': email, 'otp': otp}),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      if (response.statusCode == 429) {
        throw PinRecoveryException('Terlalu banyak percobaan. Silakan tunggu 1 menit lalu coba lagi.');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw PinRecoveryException('Gagal memproses respons server (${response.statusCode})');
      }

      if (response.statusCode != 200 || data['success'] != true) {
        throw PinRecoveryException(
          data['message'] ?? 'Kode OTP tidak valid.',
        );
      }

      return data['reset_token'] as String;
    } catch (e) {
      if (e is PinRecoveryException) rethrow;
      throw PinRecoveryException(
        'Gagal terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  /// 3. Reset PIN Baru
  Future<void> resetPin({
    required String email,
    required String resetToken,
    required String newPin,
    required String newPinConfirmation,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiBaseUrl/api/auth/reset-pin'),
        headers: getApiHeaders(),
        body: jsonEncode({
          'email': email,
          'reset_token': resetToken,
          'new_pin': newPin,
          'new_pin_confirmation': newPinConfirmation,
        }),
      ).timeout(const Duration(seconds: apiTimeoutSeconds));

      if (response.statusCode == 429) {
        throw PinRecoveryException('Terlalu banyak percobaan. Silakan tunggu 1 menit lalu coba lagi.');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw PinRecoveryException('Gagal memproses respons server (${response.statusCode})');
      }

      if (response.statusCode != 200 || data['success'] != true) {
        throw PinRecoveryException(
          data['message'] ?? 'Gagal mengatur ulang PIN.',
        );
      }
    } catch (e) {
      if (e is PinRecoveryException) rethrow;
      throw PinRecoveryException(
        'Gagal terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }
}
