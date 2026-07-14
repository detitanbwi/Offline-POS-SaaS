import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _licenseController = TextEditingController();
  bool _isLoading = false;

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
      AppSnackbar.showError(context, result['message'] ?? 'Aktivasi Gagal');
    }
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
                    if (kDebugMode) ...[
                      SizedBox(height: 12.h),
                      TextButton(
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          final storage = ref.read(secureStorageServiceProvider);
                          await storage.saveActivationData(
                            activationToken: 'dummy_offline_token_for_dev_bypass',
                            licenseKey: 'LIC-DEV-BYPASS-TEST',
                            encryptionKey: 'dummy_encryption_key_for_dev_bypass',
                            fingerprintHash: 'dummy_fingerprint_for_dev_bypass',
                            expiryDateStr: DateTime.now().add(const Duration(days: 365)).toIso8601String(),
                          );
                          setState(() => _isLoading = false);
                          if (!context.mounted) return;
                          AppSnackbar.showSuccess(context, 'Bypass Lisensi Berhasil!');
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
                          );
                        },
                        child: const Text('Developer Bypass (License Only)'),
                      ),
                    ],
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
