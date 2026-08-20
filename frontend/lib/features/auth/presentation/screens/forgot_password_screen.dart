import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/password_recovery_provider.dart';
import 'password_otp_verification_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  Future<void> _handleRequestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppSnackbar.showWarning(context, 'Alamat email tidak boleh kosong.');
      return;
    }

    final success = await ref.read(passwordRecoveryProvider.notifier).requestOtp(email);

    if (!mounted) return;

    if (success) {
      AppSnackbar.showSuccess(
        context,
        'Kode OTP telah dikirimkan ke email Anda.',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordOtpVerificationScreen(email: email),
        ),
      );
    } else {
      final error = ref.read(passwordRecoveryProvider).errorMessage;
      AppSnackbar.showError(context, error ?? 'Gagal meminta OTP.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordRecoveryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Lupa Password'),
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
                  Icon(Icons.mark_email_read_rounded, size: 56.r, color: AppColors.primary),
                  SizedBox(height: 16.h),
                  Text(
                    'Reset Password',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Masukkan alamat email akun Anda. Kami akan mengirimkan kode OTP 6 digit untuk mereset password.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 32.h),
                  AppTextField(
                    controller: _emailController,
                    labelText: 'Alamat Email',
                    hintText: 'contoh: admin@toko.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    enableSuggestions: false,
                    autocorrect: false,
                  ),
                  SizedBox(height: 32.h),
                  AppButton(
                    text: 'Kirim Kode OTP',
                    type: AppButtonType.primary,
                    isLoading: state.isLoading,
                    onPressed: _handleRequestOtp,
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
