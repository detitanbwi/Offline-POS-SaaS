import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/password_recovery_service.dart';

final passwordRecoveryServiceProvider = Provider<PasswordRecoveryService>((ref) {
  return PasswordRecoveryService();
});

class PasswordRecoveryState {
  final bool isLoading;
  final String? errorMessage;
  final String? resetToken;
  final bool isResetSuccess;

  const PasswordRecoveryState({
    this.isLoading = false,
    this.errorMessage,
    this.resetToken,
    this.isResetSuccess = false,
  });

  PasswordRecoveryState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? resetToken,
    bool? isResetSuccess,
    bool clearError = false,
  }) {
    return PasswordRecoveryState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resetToken: resetToken ?? this.resetToken,
      isResetSuccess: isResetSuccess ?? this.isResetSuccess,
    );
  }
}

class PasswordRecoveryNotifier extends StateNotifier<PasswordRecoveryState> {
  final PasswordRecoveryService _service;

  PasswordRecoveryNotifier(this._service) : super(const PasswordRecoveryState());

  Future<bool> requestOtp(String email) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.requestOtp(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _service.verifyOtp(email, otp);
      state = state.copyWith(isLoading: false, resetToken: token);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state.resetToken == null) {
      state = state.copyWith(
        errorMessage: 'Sesi pemulihan tidak valid. Silakan verifikasi ulang OTP.',
      );
      return false;
    }

    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.resetPassword(
        email: email,
        resetToken: state.resetToken!,
        newPassword: newPassword,
        newPasswordConfirmation: confirmPassword,
      );
      state = state.copyWith(isLoading: false, isResetSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void resetState() {
    state = const PasswordRecoveryState();
  }
}

final passwordRecoveryProvider =
    StateNotifierProvider<PasswordRecoveryNotifier, PasswordRecoveryState>((ref) {
  final service = ref.watch(passwordRecoveryServiceProvider);
  return PasswordRecoveryNotifier(service);
});
