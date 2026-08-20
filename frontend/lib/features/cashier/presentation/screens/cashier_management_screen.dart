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
    final usernameController = TextEditingController(text: cashier?.username ?? '');
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    AppDialog.show(
      context: context,
      title: isEdit ? 'Ubah Data & Reset PIN' : 'Pendaftaran Kasir Baru',
      confirmText: isEdit ? 'Simpan' : 'Daftarkan',
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              labelText: 'Nama Lengkap Kasir (Nama Pengguna)',
              hintText: 'Contoh: Budi Santoso',
              prefixIcon: Icons.person_outline_rounded,
              maxLength: 50,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: AppSpacing.m),
            AppTextField(
              controller: usernameController,
              labelText: 'Username (Akun Login)',
              hintText: 'Contoh: budi_s (tanpa spasi)',
              prefixIcon: Icons.account_circle_outlined,
              maxLength: 30,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Username tidak boleh kosong';
                }
                if (val.trim().contains(' ')) {
                  return 'Username tidak boleh mengandung spasi';
                }
                return null;
              },
            ),
            SizedBox(height: AppSpacing.m),
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
      onConfirm: () async {
        if (formKey.currentState?.validate() ?? false) {
          // Mencegah IME freeze: Pastikan keyboard tertutup sepenuhnya
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 300));

          final notifier = ref.read(cashierNotifierProvider.notifier);
          bool success;
          
          if (isEdit) {
            success = await notifier.updateCashier(
              cashier.id,
              nameController.text.trim(),
              usernameController.text.trim(),
              pinController.text.isNotEmpty ? pinController.text : null,
            );
          } else {
            success = await notifier.addCashier(
              nameController.text.trim(),
              usernameController.text.trim(),
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
    );
  }

  void _confirmDeleteCashier(BuildContext context, CashierModel cashier) {
    AppDialog.showConfirmDelete(
      context: context,
      title: 'Hapus Akses Kasir',
      itemName: cashier.nama,
      onDelete: () async {
        final notifier = ref.read(cashierNotifierProvider.notifier);
        await notifier.deleteCashier(cashier.id);
        
        if (!context.mounted) return;
        Navigator.pop(context); // Close the dialog
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
      final q = _searchQuery.toLowerCase();
      return cashier.nama.toLowerCase().contains(q) || cashier.username.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Kelola Akun Kasir'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded),
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
                          separatorBuilder: (context, index) => SizedBox(height: 8),
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
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cashier.nama,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.titleMedium.copyWith(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                            decoration: cashier.isActive ? null : TextDecoration.lineThrough,
                                            color: cashier.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                                          ),
                                        ),
                                         SizedBox(height: 4),
                                         Wrap(
                                           crossAxisAlignment: WrapCrossAlignment.center,
                                           spacing: 6,
                                           runSpacing: 2,
                                           children: [
                                             Text(
                                               '@${cashier.username}',
                                               style: AppTypography.bodySmall.copyWith(
                                                 color: AppColors.textSecondary,
                                                 fontWeight: FontWeight.w600,
                                               ),
                                             ),
                                             Text(
                                               '•',
                                               style: AppTypography.bodySmall.copyWith(
                                                 color: AppColors.textSecondary,
                                               ),
                                             ),
                                             Text(
                                               cashier.isActive ? 'Akses Aktif' : 'Akses Nonaktif',
                                               style: AppTypography.bodyMedium.copyWith(
                                                 fontSize: 12.sp,
                                                 color: cashier.isActive ? AppColors.success : AppColors.error,
                                                 fontWeight: FontWeight.bold,
                                               ),
                                             ),
                                           ],
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
                                    icon: Icon(Icons.edit_outlined, color: AppColors.primary),
                                    onPressed: () => _showAddEditCashierDialog(context, cashier),
                                    tooltip: 'Ubah Data & PIN',
                                  ),
                                  
                                  // Delete Button
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
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
