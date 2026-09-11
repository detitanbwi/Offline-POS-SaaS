import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/di/providers.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    return '$day $month $year';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(secureStorageServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // App Logo / Icon
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versi $appVersion (Build $appBuildNumber)',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              // System Info Card
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.divider),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Sistem',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Database Engine', 'SQLite Standard'),
                      _buildInfoRow('DB Schema Version', 'v${PosDatabase.currentDbVersion}'),
                      _buildInfoRow('Platform', Theme.of(context).platform.name.toUpperCase()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // License Status Card
              FutureBuilder<String?>(
                future: storage.getLicenseKey(),
                builder: (context, licenseSnapshot) {
                  final licenseKey = licenseSnapshot.data ?? 'Tidak Aktif';
                  return FutureBuilder<String?>(
                    future: storage.getLicenseExpiry(),
                    builder: (context, expirySnapshot) {
                      String packageExpiryStr = '-';
                      String packageDaysRemaining = '';
                      bool isExpired = false;

                      final now = DateTime.now();
                      final expiryRaw = expirySnapshot.data;

                      if (expiryRaw != null && expiryRaw.isNotEmpty) {
                        try {
                          final expiry = DateTime.parse(expiryRaw);
                          packageExpiryStr = _formatDate(expiry);
                          final diff = expiry.difference(now);
                          if (diff.isNegative) {
                            packageDaysRemaining = ' (Kedaluwarsa)';
                            isExpired = true;
                          } else {
                            packageDaysRemaining = ' (${diff.inDays} hari lagi)';
                          }
                        } catch (_) {}
                      }

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.l),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Lisensi',
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 16),
                              _buildInfoRow('License Key', licenseKey),
                              _buildInfoRow(
                                'Status Lisensi', 
                                isExpired ? 'Kedaluwarsa' : 'Aktif (Offline POS)',
                                textColor: isExpired ? AppColors.error : AppColors.success,
                              ),
                              _buildInfoRow('Kedaluwarsa Paket', '$packageExpiryStr$packageDaysRemaining'),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 48),
              Text(
                '© 2026 Kasir Pro. All rights reserved.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
