import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../../license/presentation/screens/activation_screen.dart';
import 'pin_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      AppSnackbar.showWarning(context, 'Email dan Password harus diisi!');
      return;
    }

    setState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Login Berhasil!');
      
      final storage = ref.read(secureStorageServiceProvider);
      final activationToken = await storage.getActivationToken();
      
      if (!mounted) return;
      if (activationToken == null || activationToken.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
        );
      }
    } else {
      if (!mounted) return;
      AppSnackbar.showError(context, result['message']);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480.w),
              child: AppCard(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 56.r,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "SaaS POS Offline",
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Silakan login untuk masuk ke aplikasi kasir",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    AppTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'contoh: test@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 12.h),
                    AppTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      hintText: 'Masukkan password Anda',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    SizedBox(height: 20.h),
                    AppButton(
                      text: 'Login',
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
