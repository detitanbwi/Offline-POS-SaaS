import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class LicenseLockScreen extends ConsumerStatefulWidget {
  const LicenseLockScreen({super.key});

  @override
  ConsumerState<LicenseLockScreen> createState() => _LicenseLockScreenState();
}

class _LicenseLockScreenState extends ConsumerState<LicenseLockScreen> {
  bool _isLoading = false;

  Future<void> _handleSync() async {
    setState(() => _isLoading = true);
    
    final licenseService = ref.read(licenseServiceProvider);
    final result = await licenseService.validateLicenseOnline();
    
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ref.read(licenseExpiredProvider.notifier).state = false;
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Lisensi berhasil disinkronisasi & diperbarui!');
      }
    } else {
      if (mounted) {
        AppSnackbar.showError(
          context, 
          result['message'] ?? 'Gagal melakukan sinkronisasi lisensi. Periksa koneksi internet.'
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: AppCard(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 80,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    "Sesi Lisensi Kedaluwarsa",
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.error,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    "Token lisensi luring (offline) Anda telah kedaluwarsa atau tidak valid. Silakan hubungkan tablet ke internet dan perbarui lisensi Anda.",
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    text: 'Sinkronisasi / Perbarui Lisensi',
                    isLoading: _isLoading,
                    onPressed: _handleSync,
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
