import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/stock_notifier.dart';
import '../widgets/stock_in_form.dart';
import '../widgets/stock_date_range_modal.dart';

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  void _showAddDialog(BuildContext context) {
    final productState = ref.read(productNotifierProvider);
    final stockableProducts = productState.allProducts
        .where((p) => p.isActive && !p.isPackage && p.stok != -1)
        .toList();

    if (stockableProducts.isEmpty) {
      AppSnackbar.showWarning(
        context,
        'Tidak ada produk dengan manajemen stok. Tambahkan atau aktifkan stok produk terlebih dahulu!',
      );
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

  void _openDateRangePicker(BuildContext context, StockState state) {
    StockDateRangeModal.show(
      context,
      initialStartDate: state.startDate,
      initialEndDate: state.endDate,
      onApply: (start, end) {
        ref.read(stockNotifierProvider.notifier).setDateRange(start, end);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockNotifierProvider);
    final notifier = ref.read(stockNotifierProvider.notifier);
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    final bool hasDateFilter = state.startDate != null;
    String dateRangeLabel = 'Semua Rentang Tanggal';
    if (state.startDate != null && state.endDate != null) {
      if (state.startDate == state.endDate) {
        dateRangeLabel = dateFormat.format(state.startDate!);
      } else {
        dateRangeLabel = '${dateFormat.format(state.startDate!)} - ${dateFormat.format(state.endDate!)}';
      }
    } else if (state.startDate != null) {
      dateRangeLabel = 'Mulai ${dateFormat.format(state.startDate!)}';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Mutasi Stok'),
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
            // Date Range Filter Bar (Replacing search bar)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 12),
              child: InkWell(
                onTap: () => _openDateRangePicker(context, state),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasDateFilter ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasDateFilter ? AppColors.primary : AppColors.divider,
                      width: hasDateFilter ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (hasDateFilter ? AppColors.primary : AppColors.textSecondary).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: hasDateFilter ? AppColors.primary : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rentang Tanggal Mutasi',
                              style: AppTypography.labelSmall.copyWith(
                                color: hasDateFilter ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.sp,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateRangeLabel,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasDateFilter ? AppColors.primary : AppColors.textPrimary,
                                fontSize: 13.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasDateFilter)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () => notifier.clearDateRange(),
                          tooltip: 'Reset Filter Tanggal',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      else
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            
            // Content List
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat data riwayat stok...')
                  : state.filteredStockIn.isEmpty
                      ? AppEmptyState(
                          title: 'Riwayat Mutasi Stok Kosong',
                          description: hasDateFilter
                              ? 'Tidak ada riwayat mutasi stok pada rentang tanggal terpilih.'
                              : 'Belum ada pencatatan stok masuk atau keluar.',
                          icon: Icons.assignment_outlined,
                          actionText: hasDateFilter ? 'Reset Filter Tanggal' : 'Catat Stok',
                          onActionPressed: () {
                            if (hasDateFilter) {
                              notifier.clearDateRange();
                            } else {
                              _showAddDialog(context);
                            }
                          },
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
                                                style: AppTypography.titleMedium.copyWith(fontSize: 16.sp),
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
                                              fontSize: 13.sp,
                                              fontWeight: isOut ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          'Tanggal: ${log.tanggal}',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$signPrefix${log.qty.abs()} pcs',
                                      style: AppTypography.labelLarge.copyWith(
                                        color: badgeTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp,
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
