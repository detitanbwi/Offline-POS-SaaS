import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/password_recovery_provider.dart';
import 'new_password_setup_screen.dart';

class PasswordOtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  const PasswordOtpVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<PasswordOtpVerificationScreen> createState() => _PasswordOtpVerificationScreenState();
}

class _PasswordOtpVerificationScreenState extends ConsumerState<PasswordOtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _remainingSeconds = 300; // 5 menit
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _remainingSeconds = 300;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() => _remainingSeconds--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final fullOtp = _controllers.map((c) => c.text).join();
    if (fullOtp.length == 6) {
      _verifyOtp(fullOtp);
    }
  }

  Future<void> _verifyOtp(String otpCode) async {
    final notifier = ref.read(passwordRecoveryProvider.notifier);
    final success = await notifier.verifyOtp(widget.email, otpCode);

    if (!mounted) return;

    if (success) {
      AppSnackbar.showSuccess(context, 'Verifikasi OTP berhasil!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordSetupScreen(email: widget.email),
        ),
      );
    } else {
      final error = ref.read(passwordRecoveryProvider).errorMessage;
      AppSnackbar.showError(context, error ?? 'Kode OTP tidak valid.');
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    final success = await ref.read(passwordRecoveryProvider.notifier).requestOtp(widget.email);
    if (!mounted) return;

    if (success) {
      _startTimer();
      AppSnackbar.showSuccess(
        context,
        'Kode OTP baru telah dikirimkan ke email Anda.',
      );
    } else {
      final error = ref.read(passwordRecoveryProvider).errorMessage;
      AppSnackbar.showError(context, error ?? 'Gagal mengirim ulang OTP.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordRecoveryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Verifikasi OTP Password'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.lock_clock_rounded, size: 56.r, color: AppColors.primary),
                  SizedBox(height: 16.h),
                  Text(
                    'Masukkan Kode Verifikasi',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '6 digit kode OTP telah dikirimkan ke alamat email:',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    widget.email,
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 32.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48.w,
                        height: 56.h,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          maxLength: 1,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          onChanged: (val) => _onOtpChanged(val, index),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 32.h),

                  if (state.isLoading)
                    const CircularProgressIndicator()
                  else ...[
                    if (_remainingSeconds > 0)
                      Text(
                        'Kode berakhir dalam ${_formatTimer(_remainingSeconds)}',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      )
                    else
                      TextButton.icon(
                        onPressed: _resendOtp,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Kirim Ulang Kode OTP'),
                      ),
                  ],
                  SizedBox(height: 24.h),
                  AppButton(
                    text: 'Verifikasi OTP',
                    type: AppButtonType.primary,
                    isLoading: state.isLoading,
                    onPressed: () {
                      final fullOtp = _controllers.map((c) => c.text).join();
                      if (fullOtp.length == 6) {
                        _verifyOtp(fullOtp);
                      } else {
                        AppSnackbar.showWarning(
                          context,
                          'Masukkan lengkap 6 digit kode OTP.',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
