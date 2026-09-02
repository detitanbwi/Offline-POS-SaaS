import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/password_recovery_provider.dart';

class NewPasswordSetupScreen extends ConsumerStatefulWidget {
  final String email;
  const NewPasswordSetupScreen({super.key, required this.email});

  @override
  ConsumerState<NewPasswordSetupScreen> createState() => _NewPasswordSetupScreenState();
}

class _NewPasswordSetupScreenState extends ConsumerState<NewPasswordSetupScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _handleSave() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      AppSnackbar.showWarning(context, 'Kedua kolom password harus diisi.');
      return;
    }

    if (newPassword != confirmPassword) {
      AppSnackbar.showWarning(context, 'Password baru dan konfirmasi tidak cocok.');
      return;
    }

    if (newPassword.length < 6) {
      AppSnackbar.showWarning(context, 'Password minimal harus 6 karakter.');
      return;
    }

    final success = await ref.read(passwordRecoveryProvider.notifier).resetPassword(
      email: widget.email,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (!mounted) return;

    if (success) {
      AppSnackbar.showSuccess(context, 'Password berhasil diatur ulang. Silakan login kembali.');
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      final error = ref.read(passwordRecoveryProvider).errorMessage;
      AppSnackbar.showError(context, error ?? 'Gagal mengatur ulang password.');
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordRecoveryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Buat Password Baru'),
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
                  Icon(Icons.lock_reset_rounded, size: 56.r, color: AppColors.primary),
                  SizedBox(height: 16.h),
                  Text(
                    'Password Baru',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Silakan buat password baru yang kuat untuk akun Anda (minimal 6 karakter).',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 32.h),

                  AppTextField(
                    controller: _newPasswordController,
                    labelText: 'Password Baru',
                    hintText: 'Masukkan password baru',
                    obscureText: _obscureNewPassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                  AppTextField(
                    controller: _confirmPasswordController,
                    labelText: 'Konfirmasi Password Baru',
                    hintText: 'Masukkan ulang password',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  
                  SizedBox(height: 32.h),
                  AppButton(
                    text: 'Simpan Password Baru',
                    type: AppButtonType.primary,
                    isLoading: state.isLoading,
                    onPressed: _handleSave,
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
