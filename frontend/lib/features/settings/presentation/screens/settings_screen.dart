import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
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
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../printer/presentation/screens/printer_setting_screen.dart';
import '../../../security/presentation/widgets/change_master_pin_modal.dart';
import '../../../../core/theme/font_size_provider.dart';
import 'about_screen.dart';
import 'store_profile_screen.dart';
import '../../../../core/utils/url_helper.dart';

import '../../../product/application/product_notifier.dart';
import '../../../category/application/category_notifier.dart';
import '../../../cashier/application/cashier_notifier.dart';
import '../../../table/application/table_notifier.dart';
import '../../../pos/application/order_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {

  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _backupDetails;

  @override
  void initState() {
    super.initState();
    _checkBackupStatus();
  }

  Future<void> _checkBackupStatus() async {
    final backupService = ref.read(backupServiceProvider);
    final details = await backupService.getBackupDetails();
    if (mounted) {
      setState(() {
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
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Pilih File Cadangan Database POS',
      );

      if (files.isEmpty || files.first.path == null) {
        return; // Pengguna membatalkan pemilihan file
      }

      final pickedPath = files.first.path!;
      final pickedName = files.first.name;

      if (!mounted) return;

      AppDialog.show(
        context: context,
        title: 'Pulihkan Database',
        message: 'Apakah Anda yakin ingin memulihkan database dari file "$pickedName"? Data transaksi saat ini akan ditimpa dengan data cadangan tersebut.',
        confirmText: 'Pulihkan Database',
        isDestructive: true,
        onConfirm: () async {
          final backupService = ref.read(backupServiceProvider);
          final result = await backupService.restoreFromPath(pickedPath);
          if (!mounted) return;
          Navigator.pop(context); // Tutup dialog konfirmasi
          if (result['success'] == true) {
            AppSnackbar.showSuccess(context, 'Database berhasil dipulihkan dari $pickedName!');
            // Reload catalog and application state from restored database
            ref.read(productNotifierProvider.notifier).loadProducts();
            ref.read(cashierNotifierProvider.notifier).loadCashiers();
            ref.read(categoryNotifierProvider.notifier).loadCategories();
            ref.read(tableNotifierProvider.notifier).loadTables();
            ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
            _checkBackupStatus();
          } else {
            AppSnackbar.showError(context, result['message'] ?? 'Gagal memulihkan database.');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal memilih file cadangan: $e');
      }
    }
  }

  Future<void> _handleRestoreFromFile() async {
    try {
      List<PlatformFile>? result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result.isNotEmpty && result.single.path != null) {
        File file = File(result.single.path!);
        
        if (!mounted) return;

        AppDialog.show(
          context: context,
          title: 'Paksa Pemulihan (Darurat)',
          message: 'Apakah Anda yakin ingin memaksa pemulihan database dari file terpilih? Data transaksi saat ini akan ditimpa TANPA VALIDASI.',
          confirmText: 'Paksa Pulihkan',
          isDestructive: true,
          onConfirm: () async {
            final backupService = ref.read(backupServiceProvider);
            final success = await backupService.restoreBackupFromFile(file);
            if (!mounted) return;
            Navigator.pop(context); // Close dialog
            if (success) {
              AppSnackbar.showSuccess(context, 'Database berhasil dipulihkan dari file!');
              // Reload catalog and application state from restored database
              ref.read(productNotifierProvider.notifier).loadProducts();
              ref.read(cashierNotifierProvider.notifier).loadCashiers();
              ref.read(categoryNotifierProvider.notifier).loadCategories();
              ref.read(tableNotifierProvider.notifier).loadTables();
              ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
            } else {
              AppSnackbar.showError(context, 'Gagal memulihkan cadangan database dari file.');
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal memilih file: $e');
      }
    }
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
            Text('Log Sistem'),
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: AppColors.error),
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
              style: TextStyle(fontFamily: 'monospace', fontSize: 11.sp),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
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
          title: Text('Ukuran Font'),
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
        title: Text('Pengaturan Sistem'),
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
            SizedBox(height: 12),

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
            SizedBox(height: 12),

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
            SizedBox(height: 12),

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
              SizedBox(height: 12),
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
                        Icon(Icons.backup_rounded, color: AppColors.primary),
                        SizedBox(width: 12),
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
                      SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _backupDetails!,
                                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Cadangkan',
                            onPressed: _handleBackup,
                            icon: Icons.cloud_upload_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: 'Pulihkan Database',
                            type: AppButtonType.secondary,
                            onPressed: _handleRestore,
                            icon: Icons.settings_backup_restore_rounded,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: 'Paksa Pemulihan (Darurat)',
                        type: AppButtonType.destructive,
                        onPressed: _handleRestoreFromFile,
                        icon: Icons.folder_open_rounded,
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Info Fungsi Tombol:',
                                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text('• Cadangkan: Menyimpan data transaksi ke file.', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, height: 1.4)),
                          Text('• Pulihkan Database: Memuat data dari file secara aman (dilengkapi validasi & rollback otomatis).', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, height: 1.4)),
                          Text('• Paksa Pemulihan: Mode darurat (bypass) menimpa database tanpa validasi keamanan.', style: TextStyle(fontSize: 10.sp, color: AppColors.error, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // Diagnostic Logs Option
            _buildSettingsTile(
              context,
              title: 'Log Diagnostik',
              subtitle: 'Lihat catatan sistem, printer bluetooth, dan debug logs',
              icon: Icons.developer_board_rounded,
              onTap: _showLogsDialog,
            ),
            SizedBox(height: 12),

            // Help Center Option
            _buildSettingsTile(
              context,
              title: 'Pusat Bantuan & Layanan CS',
              subtitle: 'Buka pusat bantuan resmi di alatkasirpro.com/hubungi',
              icon: Icons.help_outline_rounded,
              onTap: () => UrlHelper.openHelpCenter(context),
            ),
            SizedBox(height: 12),

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

            if (isOwner) ...[
              const SizedBox(height: 12),
              // Logout Option for Owner/Admin
              _buildSettingsTile(
                context,
                title: 'Keluar Akun SaaS (Logout)',
                subtitle: 'Keluar dari sesi akun pemilik pada perangkat kasir ini',
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                iconContainerColor: AppColors.error.withAlpha(25),
                titleColor: AppColors.error,
                onTap: _handleAdminLogout,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleAdminLogout() {
    AppDialog.show(
      context: context,
      title: 'Keluar Akun SaaS',
      message: 'Apakah Anda yakin ingin keluar dari akun SaaS pemilik pada perangkat ini? Anda harus login kembali menggunakan email dan password untuk masuk.',
      confirmText: 'Logout',
      isDestructive: true,
      onConfirm: () async {
        Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog

        final storage = ref.read(secureStorageServiceProvider);
        await storage.clearAuthSession();
        ref.read(authSessionProvider.notifier).state = null;

        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Color? iconContainerColor,
    Color? titleColor,
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
              color: iconContainerColor ?? AppColors.primaryContainer.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 15.sp, 
                    fontWeight: FontWeight.bold,
                    color: titleColor ?? AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
