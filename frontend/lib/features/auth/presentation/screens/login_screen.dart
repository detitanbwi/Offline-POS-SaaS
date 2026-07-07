import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/services/auth_service.dart';
import 'pin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      AppSnackbar.showWarning(context, 'Email dan Password harus diisi!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Login Berhasil!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
      );
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    "SaaS POS Offline",
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Silakan login untuk masuk ke aplikasi kasir",
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    hintText: 'contoh: test@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  AppTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'Masukkan password Anda',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: AppSpacing.l),
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
    );
  }
}
