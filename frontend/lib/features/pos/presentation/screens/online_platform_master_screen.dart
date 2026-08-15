// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../application/online_platform_notifier.dart';
import '../../domain/models/online_platform.dart';

class OnlinePlatformMasterScreen extends ConsumerStatefulWidget {
  const OnlinePlatformMasterScreen({super.key});

  @override
  ConsumerState<OnlinePlatformMasterScreen> createState() => _OnlinePlatformMasterScreenState();
}

class _OnlinePlatformMasterScreenState extends ConsumerState<OnlinePlatformMasterScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog(BuildContext context, [OnlinePlatformModel? platform]) {
    final nameController = TextEditingController(text: platform?.nama ?? '');
    int status = platform?.aktif ?? 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(platform == null ? 'Tambah Platform Online' : 'Ubah Platform Online'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: nameController,
                      labelText: 'Nama Platform (Cth: GoFood, GrabFood)',
                      prefixIcon: Icons.delivery_dining_rounded,
                    ),
                    SizedBox(height: 16),
                    if (platform != null) ...[
                      Text('Status', style: AppTypography.titleMedium.copyWith(fontSize: 14.sp)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<int>(
                              title: Text('Aktif', style: TextStyle(fontSize: 14.sp)),
                              value: 1,
                              groupValue: status,
                              onChanged: (val) => setState(() => status = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<int>(
                              title: Text('Nonaktif', style: TextStyle(fontSize: 14.sp)),
                              value: 0,
                              groupValue: status,
                              onChanged: (val) => setState(() => status = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      AppSnackbar.showWarning(context, 'Nama platform wajib diisi.');
                      return;
                    }

                    // Mencegah IME freeze dengan menutup keyboard dan menunggu sebelum pop dialog
                    FocusScope.of(context).unfocus();
                    await Future.delayed(const Duration(milliseconds: 300));
                    
                    if (!context.mounted) return;
                    Navigator.pop(context);

                    bool success;
                    if (platform == null) {
                      success = await ref.read(onlinePlatformNotifierProvider.notifier).addPlatform(name);
                    } else {
                      success = await ref.read(onlinePlatformNotifierProvider.notifier).updatePlatform(platform.id, name, status);
                    }

                    if (!context.mounted) return;
                    final state = ref.read(onlinePlatformNotifierProvider);
                    if (success) {
                      AppSnackbar.showSuccess(
                        context,
                        platform == null ? 'Platform berhasil ditambahkan!' : 'Platform berhasil diperbarui!',
                      );
                    } else if (state.errorMessage != null) {
                      AppSnackbar.showError(context, state.errorMessage!);
                    }
                  },
                  child: Text('Simpan'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, OnlinePlatformModel platform) {
    AppDialog.showConfirmDelete(
      context: context,
      title: 'Hapus Platform Online',
      itemName: platform.nama,
      onDelete: () async {
        Navigator.pop(context);
        final success = await ref.read(onlinePlatformNotifierProvider.notifier).deletePlatform(platform.id);
        
        if (!context.mounted) return;
        final state = ref.read(onlinePlatformNotifierProvider);
        if (success) {
          AppSnackbar.showSuccess(context, 'Platform "${platform.nama}" berhasil dihapus!');
        } else if (state.errorMessage != null) {
          AppSnackbar.showError(context, state.errorMessage!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onlinePlatformNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Master Data Platform Online'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => ref.read(onlinePlatformNotifierProvider.notifier).loadPlatforms(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context),
        icon: Icon(Icons.add_rounded),
        label: Text('Tambah'),
      ),
      body: SafeArea(
        child: state.isLoading && state.platforms.isEmpty
            ? const AppLoading(message: 'Memuat data platform...')
            : state.platforms.isEmpty
                ? AppEmptyState(
                    title: 'Belum Ada Platform',
                    description: 'Tambahkan platform online (misal: GoFood, GrabFood) untuk mendukung opsi Take Away Online.',
                    icon: Icons.delivery_dining_rounded,
                    actionText: 'Tambah Platform',
                    onActionPressed: () => _showAddEditDialog(context),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.l).copyWith(bottom: 100),
                    itemCount: state.platforms.length,
                    itemBuilder: (context, index) {
                      final platform = state.platforms[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: platform.isActive ? AppColors.primaryContainer : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delivery_dining_rounded,
                                color: platform.isActive ? AppColors.primary : Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    platform.nama,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: platform.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: platform.isActive ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: platform.isActive ? AppColors.success.withValues(alpha: 0.5) : Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Text(
                                      platform.isActive ? 'Aktif' : 'Nonaktif',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: platform.isActive ? AppColors.success : Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_rounded, color: AppColors.primary),
                              onPressed: () => _showAddEditDialog(context, platform),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              onPressed: () => _confirmDelete(context, platform),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
