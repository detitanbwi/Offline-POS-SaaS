import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
class LicenseLockScreen extends ConsumerStatefulWidget {
  const LicenseLockScreen({super.key});

  @override
  ConsumerState<LicenseLockScreen> createState() => _LicenseLockScreenState();
}

class _LicenseLockScreenState extends ConsumerState<LicenseLockScreen> {
  bool _isLoading = false;

  Future<void> _handleSync() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 100)); // Allow UI to render loading state
    
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
        final isAuthError = result['message'] == 'Data aktivasi tidak lengkap' || result['message'] == 'Perangkat tidak terdaftar';
        
        if (isAuthError) {
          final storage = ref.read(secureStorageServiceProvider);
          await storage.clearAll();
          
          if (mounted) {
            // Buka blokir UI
            ref.read(licenseExpiredProvider.notifier).state = false;

            final errorMessage = result['message'] == 'Perangkat tidak terdaftar' 
                ? 'Perangkat tidak terdaftar. Silakan login kembali.' 
                : 'Sesi tidak valid. Silakan login kembali.';

            AppSnackbar.showError(context, errorMessage);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        } else {
          AppSnackbar.showError(
            context, 
            result['message'] ?? 'Gagal melakukan sinkronisasi lisensi. Periksa koneksi internet.'
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480.w),
              child: AppCard(
                color: Colors.white,
                padding: EdgeInsets.all(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 56.r,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "Sesi Lisensi Kedaluwarsa",
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "Token lisensi luring (offline) Anda telah kedaluwarsa atau tidak valid. Silakan hubungkan tablet ke internet dan perbarui lisensi Anda.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 20.h),
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
      ),
    );
  }
}
