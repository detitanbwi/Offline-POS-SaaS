import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import 'license_log_screen.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(secureStorageServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Tentang Aplikasi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 24),
              // App Logo / Icon Placeholder
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.point_of_sale_rounded,
                    color: AppColors.primary,
                    size: 64,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Versi $appVersion (Build $appBuildNumber)',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(height: 32),
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
                      _buildInfoRow('Database Engine', 'SQLite (SQLCipher Encrypted)'),
                      _buildInfoRow('DB Schema Version', 'v$posDatabaseVersion'),
                      _buildInfoRow('Platform', Theme.of(context).platform.name.toUpperCase()),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              // License Status Card
              FutureBuilder<String?>(
                future: storage.getLicenseKey(),
                builder: (context, snapshot) {
                  final licenseKey = snapshot.data ?? 'Tidak Aktif';
                  return StreamBuilder<DateTime>(
                    stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                    builder: (context, timerSnapshot) {
                      return FutureBuilder<String?>(
                        future: storage.getLicenseExpiry(),
                        builder: (context, expirySnapshot) {
                          String countdown = '-';
                          String expiryDate = '-';
                          
                          if (expirySnapshot.data != null && expirySnapshot.data!.isNotEmpty) {
                            try {
                              final expiry = DateTime.parse(expirySnapshot.data!);
                              expiryDate = expiry.toLocal().toString().split('.')[0];
                              
                              final now = DateTime.now();
                              final difference = expiry.difference(now);
                              
                              if (difference.isNegative) {
                                countdown = 'Kadaluwarsa';
                              } else {
                                final days = difference.inDays;
                                final hours = difference.inHours % 24;
                                final minutes = difference.inMinutes % 60;
                                final seconds = difference.inSeconds % 60;
                                countdown = '${days}h ${hours}j ${minutes}m ${seconds}d';
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Status Lisensi',
                                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.history_rounded, color: AppColors.primary),
                                        tooltip: 'Log Aktivitas Lisensi',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const LicenseLogScreen()),
                                          );
                                        },
                                      )
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow('License Key', licenseKey),
                                  _buildInfoRow('Sisa Waktu', countdown),
                                  _buildInfoRow('Kedaluwarsa', expiryDate),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  );
                },
              ),
              SizedBox(height: 48),
              Text(
                '© 2026 Wirodev SaaS POS. All rights reserved.',
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
