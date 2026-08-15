import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/pin_recovery_provider.dart';
import '../screens/otp_verification_screen.dart';

class ForgotPinEmailModal extends ConsumerStatefulWidget {
  const ForgotPinEmailModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ForgotPinEmailModal(),
    );
  }

  @override
  ConsumerState<ForgotPinEmailModal> createState() => _ForgotPinEmailModalState();
}

class _ForgotPinEmailModalState extends ConsumerState<ForgotPinEmailModal> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppSnackbar.showError(context, 'Masukkan alamat email yang valid.');
      return;
    }

    final notifier = ref.read(pinRecoveryProvider.notifier);
    final success = await notifier.requestOtp(email);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(
        context,
        'Kode OTP pemulihan PIN telah dikirim ke $email',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(email: email),
        ),
      );
    } else {
      final error = ref.read(pinRecoveryProvider).errorMessage;
      AppSnackbar.showError(context, error ?? 'Gagal meminta kode OTP.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinRecoveryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440.w),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.mark_email_read_rounded, size: 52.r, color: AppColors.primary),
              SizedBox(height: 12.h),
              Text(
                'Lupa PIN POS (OTP Email)',
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                'Masukkan email akun Anda. Kami akan mengirimkan 6 digit kode OTP verifikasi untuk mengatur ulang PIN.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Alamat Email Terdaftar',
                  hintText: 'Contoh: owner@toko.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              if (state.errorMessage != null) ...[
                SizedBox(height: 12.h),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: state.isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: AppButton(
                      text: 'Kirim Kode OTP',
                      type: AppButtonType.primary,
                      isLoading: state.isLoading,
                      onPressed: _submitRequest,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
