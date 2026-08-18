import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pin_recovery_service.dart';

final pinRecoveryServiceProvider = Provider<PinRecoveryService>((ref) {
  return PinRecoveryService();
});

class PinRecoveryState {
  final bool isLoading;
  final String? errorMessage;
  final String? resetToken;
  final bool isResetSuccess;

  const PinRecoveryState({
    this.isLoading = false,
    this.errorMessage,
    this.resetToken,
    this.isResetSuccess = false,
  });

  PinRecoveryState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? resetToken,
    bool? isResetSuccess,
    bool clearError = false,
  }) {
    return PinRecoveryState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resetToken: resetToken ?? this.resetToken,
      isResetSuccess: isResetSuccess ?? this.isResetSuccess,
    );
  }
}

class PinRecoveryNotifier extends StateNotifier<PinRecoveryState> {
  final PinRecoveryService _service;

  PinRecoveryNotifier(this._service) : super(const PinRecoveryState());

  Future<bool> requestOtp(String email) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.requestOtp(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> resetPin({
    required String email,
    required String newPin,
    required String confirmPin,
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
      await _service.resetPin(
        email: email,
        resetToken: state.resetToken!,
        newPin: newPin,
        newPinConfirmation: confirmPin,
      );
      state = state.copyWith(isLoading: false, isResetSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  void resetState() {
    state = const PinRecoveryState();
  }
}

final pinRecoveryProvider =
    StateNotifierProvider<PinRecoveryNotifier, PinRecoveryState>((ref) {
  final service = ref.watch(pinRecoveryServiceProvider);
  return PinRecoveryNotifier(service);
});
