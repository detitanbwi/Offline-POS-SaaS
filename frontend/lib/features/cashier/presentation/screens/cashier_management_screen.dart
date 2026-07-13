import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../application/cashier_notifier.dart';
import '../../domain/models/cashier.dart';


class CashierManagementScreen extends ConsumerStatefulWidget {
  const CashierManagementScreen({super.key});

  @override
  ConsumerState<CashierManagementScreen> createState() => _CashierManagementScreenState();
}

class _CashierManagementScreenState extends ConsumerState<CashierManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditCashierDialog(BuildContext context, [CashierModel? cashier]) {
    final isEdit = cashier != null;
    final nameController = TextEditingController(text: cashier?.nama ?? '');
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEdit ? 'Ubah Data & Reset PIN' : 'Pendaftaran Kasir Baru',
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    labelText: 'Nama Lengkap Kasir',
                    hintText: 'Masukkan nama kasir',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  AppTextField(
                    controller: pinController,
                    labelText: isEdit ? 'Reset PIN (6 Digit, Opsional)' : 'PIN Sesi (6 Digit)',
                    hintText: isEdit ? 'Kosongkan jika tidak ingin diubah' : 'Masukkan 6 digit angka',
                    prefixIcon: Icons.lock_outline_rounded,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    validator: (val) {
                      if (!isEdit && (val == null || val.length != 6)) {
                        return 'PIN harus 6 digit angka';
                      }
                      if (isEdit && val != null && val.isNotEmpty && val.length != 6) {
                        return 'PIN baru harus 6 digit angka';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final notifier = ref.read(cashierNotifierProvider.notifier);
                  bool success;
                  
                  if (isEdit) {
                    success = await notifier.updateCashier(
                      cashier.id,
                      nameController.text.trim(),
                      pinController.text.isNotEmpty ? pinController.text : null,
                    );
                  } else {
                    success = await notifier.addCashier(
                      nameController.text.trim(),
                      pinController.text,
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  final state = ref.read(cashierNotifierProvider);
                  if (success) {
                    AppSnackbar.showSuccess(context, state.successMessage ?? 'Operasi Berhasil!');
                  } else {
                    AppSnackbar.showError(context, state.errorMessage ?? 'Operasi Gagal!');
                  }
                }
              },
              child: Text(isEdit ? 'Simpan' : 'Daftarkan'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCashier(BuildContext context, CashierModel cashier) {
    AppDialog.show(
      context: context,
      title: 'Hapus Akses Kasir',
      message: 'Apakah Anda yakin ingin menghapus akses kasir "${cashier.nama}"? Shift transaksi kasir ini akan dipertahankan namun kasir tidak bisa masuk lagi.',
      confirmText: 'Hapus Akses',
      cancelText: 'Batal',
      isDestructive: true,
      onConfirm: () async {
        final notifier = ref.read(cashierNotifierProvider.notifier);
        await notifier.deleteCashier(cashier.id);
        
        if (!context.mounted) return;
        final state = ref.read(cashierNotifierProvider);
        if (state.errorMessage != null) {
          AppSnackbar.showError(context, state.errorMessage!);
        } else {
          AppSnackbar.showSuccess(context, 'Akses kasir berhasil dinonaktifkan permanen.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashierNotifierProvider);
    final filteredList = state.allCashiers.where((cashier) {
      return cashier.nama.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kelola Akun Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Tambah Kasir Baru',
            onPressed: () => _showAddEditCashierDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _searchController,
                      labelText: 'Cari Kasir / Karyawan',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            
            // List / content
            Expanded(
              child: state.isLoading && state.allCashiers.isEmpty
                  ? const AppLoading(message: 'Memuat data kasir...')
                  : filteredList.isEmpty
                      ? AppEmptyState(
                          title: _searchQuery.isNotEmpty ? 'Kasir Tidak Ditemukan' : 'Belum Ada Kasir',
                          description: _searchQuery.isNotEmpty
                              ? 'Coba ubah kata kunci pencarian Anda.'
                              : 'Silakan klik tombol tambah (+) di kanan atas untuk mendaftarkan akun kasir baru.',
                          icon: Icons.people_outline_rounded,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          itemCount: filteredList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final cashier = filteredList[index];
                            return AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: cashier.isActive 
                                        ? AppColors.primaryContainer.withValues(alpha: 0.6) 
                                        : Colors.grey.shade100,

                                    child: Icon(
                                      Icons.person_outline_rounded, 
                                      color: cashier.isActive ? AppColors.primary : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cashier.nama,
                                          style: AppTypography.titleMedium.copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: cashier.isActive ? null : TextDecoration.lineThrough,
                                            color: cashier.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cashier.isActive ? 'Akses Aktif' : 'Akses Nonaktif',
                                          style: AppTypography.bodyMedium.copyWith(
                                            fontSize: 12,
                                            color: cashier.isActive ? AppColors.success : AppColors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Active toggle switch
                                  Switch(
                                    value: cashier.isActive,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (_) async {
                                      final notifier = ref.read(cashierNotifierProvider.notifier);
                                      await notifier.toggleStatus(cashier.id, cashier.status);
                                      
                                      if (!context.mounted) return;
                                      final updatedState = ref.read(cashierNotifierProvider);
                                      if (updatedState.errorMessage != null) {
                                        AppSnackbar.showError(context, updatedState.errorMessage!);
                                      } else {
                                        AppSnackbar.showSuccess(context, updatedState.successMessage!);
                                      }
                                    },
                                  ),
                                  
                                  // Edit Button
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                                    onPressed: () => _showAddEditCashierDialog(context, cashier),
                                    tooltip: 'Ubah Data & PIN',
                                  ),
                                  
                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                    onPressed: () => _confirmDeleteCashier(context, cashier),
                                    tooltip: 'Hapus Kasir',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
