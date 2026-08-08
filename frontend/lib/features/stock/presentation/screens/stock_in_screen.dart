import 'package:flutter/material.dart';
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
import '../../../product/application/product_notifier.dart';
import '../../application/stock_notifier.dart';
import '../widgets/stock_in_form.dart';

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDialog(BuildContext context) {
    final productState = ref.read(productNotifierProvider);
    final activeProducts = productState.allProducts.where((p) => p.isActive).toList();

    if (activeProducts.isEmpty) {
      AppSnackbar.showWarning(context, 'Tidak ada Produk Aktif. Silakan tambah produk terlebih dahulu!');
      return;
    }

    final formKey = GlobalKey<StockInFormState>();

    AppDialog.show(
      context: context,
      title: 'Catat Mutasi Stok (Masuk/Keluar)',
      confirmText: 'Simpan',
      content: StockInForm(
        key: formKey,
        products: productState.allProducts,
        onSubmit: ({
          required String produkId,
          required String type,
          required int qty,
          required String tanggal,
          String? catatan,
        }) async {
          Navigator.pop(context); // close dialog

          final success = await ref.read(stockNotifierProvider.notifier).addStockIn(
                produkId: produkId,
                type: type,
                qty: qty,
                tanggal: tanggal,
                catatan: catatan,
              );

          if (!context.mounted) return;
          final state = ref.read(stockNotifierProvider);
          if (success) {
            final msg = type == 'in' ? 'Stok masuk berhasil dicatat!' : 'Stok keluar/minus berhasil dicatat!';
            AppSnackbar.showSuccess(context, msg);
          } else if (state.errorMessage != null) {
            AppSnackbar.showError(context, state.errorMessage!);
          }
        },
      ),
      onConfirm: () {
        formKey.currentState?.submit();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockNotifierProvider);
    final notifier = ref.read(stockNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Manajemen Stok (In & Out)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.swap_vert_rounded),
        label: const Text('Catat Stok'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: AppTextField(
                controller: _searchController,
                labelText: 'Cari Riwayat Mutasi Stok',
                prefixIcon: Icons.search,
                onChanged: (val) => notifier.setSearchQuery(val),
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat data riwayat stok...')
                  : state.filteredStockIn.isEmpty
                      ? AppEmptyState(
                          title: 'Riwayat Mutasi Stok Kosong',
                          description: _searchController.text.isNotEmpty
                              ? 'Tidak ada riwayat stok yang cocok dengan pencarian Anda.'
                              : 'Belum ada pencatatan stok masuk atau keluar.',
                          icon: Icons.assignment_outlined,
                          actionText: _searchController.text.isNotEmpty ? null : 'Catat Stok',
                          onActionPressed: () => _showAddDialog(context),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m).copyWith(bottom: 100),
                          itemCount: state.filteredStockIn.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = state.filteredStockIn[index];
                            final isOut = log.isOut;
                            final iconColor = isOut ? AppColors.error : AppColors.success;
                            final badgeBg = isOut
                                ? AppColors.error.withValues(alpha: 0.1)
                                : AppColors.primaryContainer;
                            final badgeTextColor = isOut ? AppColors.error : AppColors.primary;
                            final signPrefix = isOut ? '-' : '+';

                            return AppCard(
                              padding: const EdgeInsets.all(16),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isOut ? Icons.indeterminate_check_box_outlined : Icons.add_box_outlined,
                                      color: iconColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                log.produkNama ?? 'Produk Tidak Diketahui',
                                                style: AppTypography.titleMedium.copyWith(fontSize: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (log.catatan != null && log.catatan!.isNotEmpty) ...[
                                          Text(
                                            log.catatan!,
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: isOut ? AppColors.textPrimary : AppColors.textSecondary,
                                              fontSize: 13,
                                              fontWeight: isOut ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          'Tanggal: ${log.tanggal}',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$signPrefix${log.qty.abs()}',
                                      style: TextStyle(
                                        color: badgeTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
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
