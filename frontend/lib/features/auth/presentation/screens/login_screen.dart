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
import 'forgot_password_screen.dart';
import 'package:airplane_mode_checker/airplane_mode_checker.dart';
import 'dart:async';
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isAirplaneModeOn = false;
  StreamSubscription? _airplaneModeSub;

  @override
  void initState() {
    super.initState();
    _checkAirplaneMode();
    _airplaneModeSub = AirplaneModeChecker.instance.listenAirplaneMode().listen((status) {
      if (mounted) {
        final isOn = status == AirplaneModeStatus.on;
        if (_isAirplaneModeOn != isOn) {
          setState(() {
            _isAirplaneModeOn = isOn;
          });
        }
      }
    });
  }

  Future<void> _checkAirplaneMode() async {
    try {
      final status = await AirplaneModeChecker.instance.checkAirplaneMode();
      if (mounted) {
        setState(() {
          _isAirplaneModeOn = status == AirplaneModeStatus.on;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus(); // Dismiss keyboard to prevent IME freeze

    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      AppSnackbar.showWarning(context, 'Email dan Password harus diisi!');
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300)); // Allow UI to render loading state and keyboard to hide completely

    final authService = ref.read(authServiceProvider);
    final result = await authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
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
      AppSnackbar.showError(context, result['message']);
    }
  }

  @override
  void dispose() {
    _airplaneModeSub?.cancel();
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
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
                    if (_isAirplaneModeOn) ...[
                      SizedBox(height: 16.h),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border.all(color: Colors.amber.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Mohon nonaktifkan Mode Pesawat (Airplane Mode) selama proses login berlangsung agar waktu perangkat dapat disinkronkan dengan server. Setelah berhasil login, Mode Pesawat dapat diaktifkan kembali dan aplikasi tetap berfungsi secara offline.",
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 24.h),
                    AppTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'contoh: test@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    SizedBox(height: 12.h),
                    AppTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      hintText: 'Masukkan password Anda',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    SizedBox(height: 8.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Lupa Password?',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
