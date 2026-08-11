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
import '../../../auth/presentation/screens/pin_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _licenseController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingToken = false;
  String? _pulledTokenKey;
  String? _pulledStoreName;

  @override
  void initState() {
    super.initState();
    _fetchLicenseInfo();
  }

  Future<void> _fetchLicenseInfo() async {
    setState(() => _isFetchingToken = true);
    final licenseService = ref.read(licenseServiceProvider);
    final result = await licenseService.getLicenseInfo();
    if (!mounted) return;
    setState(() => _isFetchingToken = false);

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      if (data['tenant'] != null) {
        _pulledStoreName = data['tenant']['store_name'] ?? data['tenant']['name'];
      }
      final tokens = data['tokens'] as List?;
      if (tokens != null && tokens.isNotEmpty) {
        // Cari token yang available atau active
        final availableToken = tokens.firstWhere(
          (t) => t['status'] == 'available' || t['status'] == 'active',
          orElse: () => tokens.first,
        );
        if (availableToken != null && availableToken['token_key'] != null) {
          setState(() {
            _pulledTokenKey = availableToken['token_key'];
            _licenseController.text = _pulledTokenKey!;
          });
        }
      }
    }
  }

  Future<void> _handleActivation() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) {
      AppSnackbar.showWarning(context, 'Lisensi Key harus diisi!');
      return;
    }

    setState(() => _isLoading = true);

    final licenseService = ref.read(licenseServiceProvider);
    final result = await licenseService.activate(key);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Aktivasi Perangkat Berhasil!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
      );
    } else {
      if (!mounted) return;
      if (result['message'] == 'Token sudah digunakan pada perangkat lain. Hubungi admin untuk reset.') {
        _showResetDeviceDialog();
      } else {
        AppSnackbar.showError(context, result['message'] ?? 'Aktivasi Gagal');
      }
    }
  }

  void _showResetDeviceDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isRequesting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Reset Perangkat', style: AppTypography.titleLarge.copyWith(color: AppColors.primary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Token ini sudah terikat ke perangkat lain. Masukkan email dan password pemilik lisensi untuk mereset perangkat.', style: AppTypography.bodyMedium),
                    SizedBox(height: 16.h),
                    AppTextField(
                      controller: emailController,
                      labelText: 'Email',
                      hintText: 'admin@toko.com',
                      prefixIcon: Icons.email_rounded,
                    ),
                    SizedBox(height: 16.h),
                    AppTextField(
                      controller: passwordController,
                      labelText: 'Password',
                      hintText: 'Masukkan password Anda',
                      prefixIcon: Icons.lock_rounded,
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isRequesting ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                AppButton(
                  text: 'Kirim OTP',
                  isLoading: isRequesting,
                  onPressed: () async {
                    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                      AppSnackbar.showWarning(context, 'Email dan password harus diisi');
                      return;
                    }
                    setStateDialog(() => isRequesting = true);
                    final licenseService = ref.read(licenseServiceProvider);
                    final result = await licenseService.requestDeviceResetOtp(
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      tokenKey: _licenseController.text.trim(),
                    );
                    setStateDialog(() => isRequesting = false);

                    if (result['success'] == true) {
                      if (!context.mounted) return;
                      Navigator.pop(context); // Tutup dialog auth
                      _showVerifyOtpDialog(emailController.text.trim());
                    } else {
                      if (!context.mounted) return;
                      AppSnackbar.showError(context, result['message']);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showVerifyOtpDialog(String email) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Verifikasi OTP', style: AppTypography.titleLarge.copyWith(color: AppColors.primary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Masukkan 6 digit kode OTP yang dikirim ke email $email', style: AppTypography.bodyMedium),
                  SizedBox(height: 16.h),
                  AppTextField(
                    controller: otpController,
                    labelText: 'Kode OTP',
                    hintText: '123456',
                    prefixIcon: Icons.security_rounded,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                AppButton(
                  text: 'Verifikasi & Reset',
                  isLoading: isVerifying,
                  onPressed: () async {
                    if (otpController.text.length != 6) {
                      AppSnackbar.showWarning(context, 'Kode OTP harus 6 digit');
                      return;
                    }
                    setStateDialog(() => isVerifying = true);
                    final licenseService = ref.read(licenseServiceProvider);
                    final result = await licenseService.verifyDeviceResetOtp(
                      email: email,
                      tokenKey: _licenseController.text.trim(),
                      otp: otpController.text.trim(),
                    );
                    setStateDialog(() => isVerifying = false);

                    if (result['success'] == true) {
                      if (!context.mounted) return;
                      Navigator.pop(context); // Tutup dialog OTP
                      AppSnackbar.showSuccess(context, 'Perangkat berhasil di-reset. Mengaktifkan...');
                      _handleActivation(); // Coba aktivasi lagi otomatis
                    } else {
                      if (!context.mounted) return;
                      AppSnackbar.showError(context, result['message']);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () async {
            final storage = ref.read(secureStorageServiceProvider);
            await storage.clearAll();
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
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
                      Icons.verified_user_rounded,
                      size: 56.r,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "Aktivasi Lisensi",
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Masukkan Lisensi Key Anda untuk mengaktifkan perangkat POS ini",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_isFetchingToken) ...[
                      SizedBox(height: 12.h),
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_pulledTokenKey != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20.r),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                "Lisensi Ditemukan untuk ${_pulledStoreName ?? 'Toko Anda'}",
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 20.h),
                    AppTextField(
                      controller: _licenseController,
                      labelText: 'Lisensi Key',
                      hintText: 'LIC-XXXX-XXXX-XXXX',
                      prefixIcon: Icons.key_rounded,
                    ),
                    SizedBox(height: 16.h),
                    AppButton(
                      text: 'Aktifkan Perangkat',
                      isLoading: _isLoading,
                      onPressed: _handleActivation,
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
