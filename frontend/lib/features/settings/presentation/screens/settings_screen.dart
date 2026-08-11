import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../printer/presentation/screens/printer_setting_screen.dart';
import '../../../security/presentation/widgets/change_master_pin_modal.dart';
import '../../../../core/theme/font_size_provider.dart';
import 'about_screen.dart';
import 'store_profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {

  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _backupDetails;
  bool _hasBackup = false;

  @override
  void initState() {
    super.initState();
    _checkBackupStatus();
  }

  Future<void> _checkBackupStatus() async {
    final backupService = ref.read(backupServiceProvider);
    final hasBkp = await backupService.hasBackup();
    final details = await backupService.getBackupDetails();
    if (mounted) {
      setState(() {
        _hasBackup = hasBkp;
        _backupDetails = details;
      });
    }
  }

  Future<void> _handleBackup() async {
    final backupService = ref.read(backupServiceProvider);
    final success = await backupService.createBackup();
    if (mounted) {
      if (success) {
        AppSnackbar.showSuccess(context, 'Pencadangan database berhasil disimpan!');
        _checkBackupStatus();
      } else {
        AppSnackbar.showError(context, 'Gagal mencadangkan database. Cek log.');
      }
    }
  }

  Future<void> _handleRestore() async {
    AppDialog.show(
      context: context,
      title: 'Pulihkan Database',
      message: 'Apakah Anda yakin ingin memulihkan database dari cadangan terakhir? Data transaksi saat ini akan ditimpa.',
      confirmText: 'Pulihkan',
      isDestructive: true,
      onConfirm: () async {
        final backupService = ref.read(backupServiceProvider);
        final success = await backupService.restoreBackup();
        if (!mounted) return;
        Navigator.pop(context); // Close dialog
        if (success) {
          AppSnackbar.showSuccess(context, 'Database berhasil dipulihkan!');
          // Refresh products to reload catalog state
          ref.read(productRepositoryProvider); 
        } else {
          AppSnackbar.showError(context, 'Gagal memulihkan cadangan database.');
        }
      },
    );
  }

  void _showLogsDialog() async {
    final logs = await AppLogger.readLogs();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Log Sistem'),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
              tooltip: 'Bersihkan Log',
              onPressed: () async {
                await AppLogger.clearLogs();
                if (!context.mounted) return;
                Navigator.pop(context);
                AppSnackbar.showSuccess(context, 'Log sistem dibersihkan.');
              },
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              logs,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ukuran Font'),
          content: Consumer(
            builder: (context, ref, child) {
              final currentSize = ref.watch(fontSizeProvider);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: AppFontSize.values.map((size) {
                  return RadioListTile<AppFontSize>(
                    title: Text(size.label),
                    value: size,
                    groupValue: currentSize,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(fontSizeProvider.notifier).setFontSize(value);
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = ref.watch(authSessionProvider);
    final isOwner = activeUser?.isOwner ?? false;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Pengaturan Sistem'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            // Store Profile Option
            _buildSettingsTile(
              context,
              title: 'Profil & Informasi Toko',
              subtitle: 'Atur nama toko, alamat lengkap, dan nomor telepon cetakan struk',
              icon: Icons.storefront_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Printers Config Option
            _buildSettingsTile(
              context,
              title: 'Konfigurasi Printer',
              subtitle: 'Atur printer kasir bluetooth & kitchen ticket',
              icon: Icons.print_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrinterSettingScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Font Size Option
            _buildSettingsTile(
              context,
              title: 'Ukuran Font',
              subtitle: 'Atur skala ukuran teks di seluruh aplikasi',
              icon: Icons.text_fields_rounded,
              onTap: () {
                _showFontSizeDialog();
              },
            ),
            const SizedBox(height: 12),

            if (isOwner) ...[
              // Change Master PIN Option (Sisi Master)
              _buildSettingsTile(
                context,
                title: 'Ubah PIN Master',
                subtitle: 'Ganti PIN Master keamanan dengan memasukkan PIN lama',
                icon: Icons.lock_reset_rounded,
                onTap: () {
                  ChangeMasterPinModal.show(context);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Backup & Restore Card

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
                    Row(
                      children: [
                        const Icon(Icons.backup_rounded, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Pencadangan Database',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Cadangkan seluruh data transaksi, meja, produk, dan pengaturan sistem secara berkala.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    if (_backupDetails != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _backupDetails!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Cadangkan',
                            onPressed: _handleBackup,
                            icon: Icons.cloud_upload_outlined,
                          ),
                        ),
                        if (_hasBackup) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              text: 'Pulihkan',
                              type: AppButtonType.secondary,
                              onPressed: _handleRestore,
                              icon: Icons.settings_backup_restore_rounded,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Diagnostic Logs Option
            _buildSettingsTile(
              context,
              title: 'Log Diagnostik',
              subtitle: 'Lihat catatan sistem, printer bluetooth, dan debug logs',
              icon: Icons.developer_board_rounded,
              onTap: _showLogsDialog,
            ),
            const SizedBox(height: 12),

            // About App Option
            _buildSettingsTile(
              context,
              title: 'Tentang Aplikasi',
              subtitle: 'Informasi sistem POS, lisensi aktif, dan versi rilis',
              icon: Icons.info_outline_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderSide: const BorderSide(color: AppColors.divider),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
