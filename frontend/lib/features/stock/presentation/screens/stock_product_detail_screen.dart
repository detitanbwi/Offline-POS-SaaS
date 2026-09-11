import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../product/domain/models/product.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/stock_notifier.dart';
import '../../domain/models/stock_in.dart';
import '../widgets/stock_date_range_modal.dart';

class StockProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const StockProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<StockProductDetailScreen> createState() => _StockProductDetailScreenState();
}

class _StockProductDetailScreenState extends ConsumerState<StockProductDetailScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  void _openDateRangePicker(BuildContext context) {
    StockDateRangeModal.show(
      context,
      initialStartDate: _startDate,
      initialEndDate: _endDate,
      onApply: (start, end) {
        setState(() {
          _startDate = start;
          _endDate = end;
        });
      },
    );
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockNotifierProvider);
    final productState = ref.watch(productNotifierProvider);

    // Get real-time product data
    final currentProduct = productState.allProducts.firstWhere(
      (p) => p.id == widget.product.id,
      orElse: () => widget.product,
    );

    // 1. Get ALL mutations for this product (unfiltered) sorted newest first
    final allProductMutations = stockState.allStockIn
        .where((s) => s.produkId == currentProduct.id)
        .toList()
      ..sort((a, b) {
        final dateComp = b.tanggal.compareTo(a.tanggal);
        if (dateComp != 0) return dateComp;
        return b.createdAt.compareTo(a.createdAt);
      });

    // 2. Precompute running balance (saldo stok setelah mutasi) for every mutation
    final Map<String, int> runningBalanceMap = {};
    if (currentProduct.stok != -1) {
      int runningBalance = currentProduct.stok;
      for (int i = 0; i < allProductMutations.length; i++) {
        final m = allProductMutations[i];
        runningBalanceMap[m.id] = runningBalance;
        final int netDelta = m.isOut ? -m.qty.abs() : m.qty.abs();
        runningBalance = runningBalance - netDelta;
      }
    }

    // Filter mutations for display
    List<StockIn> productMutations = List.from(allProductMutations);

    // Apply date range filter if selected
    if (_startDate != null && _endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      productMutations = productMutations.where((s) {
        return s.tanggal.compareTo(startStr) >= 0 && s.tanggal.compareTo(endStr) <= 0;
      }).toList();
    } else if (_startDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      productMutations = productMutations.where((s) => s.tanggal.compareTo(startStr) >= 0).toList();
    }

    // Calculate In / Out totals
    int totalIn = 0;
    int totalOut = 0;
    for (final m in productMutations) {
      if (m.isOut) {
        totalOut += m.qty.abs();
      } else {
        totalIn += m.qty.abs();
      }
    }

    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final bool hasDateFilter = _startDate != null;
    String dateRangeLabel = 'Semua Periode Tanggal';
    if (_startDate != null && _endDate != null) {
      if (_startDate == _endDate) {
        dateRangeLabel = dateFormat.format(_startDate!);
      } else {
        dateRangeLabel = '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}';
      }
    } else if (_startDate != null) {
      dateRangeLabel = 'Mulai ${dateFormat.format(_startDate!)}';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Kartu Stok: ${currentProduct.nama}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Product Summary Header Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          currentProduct.isPackage ? Icons.inventory_2_outlined : Icons.inventory_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProduct.nama,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Harga: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(currentProduct.harga)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: currentProduct.stok == 0
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: currentProduct.stok == 0
                                ? AppColors.error.withValues(alpha: 0.3)
                                : AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Sisa Stok',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.sp,
                              ),
                            ),
                            Text(
                              currentProduct.stok == -1 ? 'Non-Stock' : '${currentProduct.stok} pcs',
                              style: AppTypography.titleMedium.copyWith(
                                color: currentProduct.stok == 0 ? AppColors.error : AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date Range Filter Bar
                  InkWell(
                    onTap: () => _openDateRangePicker(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: hasDateFilter ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasDateFilter ? AppColors.primary : AppColors.divider,
                          width: hasDateFilter ? 1.2 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: hasDateFilter ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dateRangeLabel,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 13.sp,
                                color: hasDateFilter ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: hasDateFilter ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasDateFilter)
                            InkWell(
                              onTap: _clearDateRange,
                              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                            )
                          else
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Period Summary (Total Masuk vs Total Keluar)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Masuk:', style: AppTypography.bodySmall.copyWith(color: AppColors.success)),
                              Text('+$totalIn pcs', style: AppTypography.titleSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Keluar:', style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                              Text('-$totalOut pcs', style: AppTypography.titleSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // Mutations List
            Expanded(
              child: stockState.isLoading
                  ? const AppLoading(message: 'Memuat riwayat kartu stok...')
                  : productMutations.isEmpty
                      ? AppEmptyState(
                          title: 'Belum Ada Riwayat Mutasi',
                          description: hasDateFilter
                              ? 'Tidak ada mutasi stok untuk produk ini pada periode tanggal terpilih.'
                              : 'Produk ini belum memiliki riwayat mutasi stok (masuk/keluar).',
                          icon: Icons.history_rounded,
                          actionText: hasDateFilter ? 'Reset Filter Tanggal' : null,
                          onActionPressed: hasDateFilter ? _clearDateRange : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m).copyWith(bottom: 40),
                          itemCount: productMutations.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = productMutations[index];
                            final isOut = log.isOut;
                            final iconColor = isOut ? AppColors.error : AppColors.success;
                            final badgeBg = isOut
                                ? AppColors.error.withValues(alpha: 0.1)
                                : AppColors.primaryContainer;
                            final badgeTextColor = isOut ? AppColors.error : AppColors.primary;
                            final signPrefix = isOut ? '-' : '+';

                            String formattedDateTime = log.tanggal;
                            try {
                              final parsedDate = DateTime.tryParse(log.tanggal);
                              if (parsedDate != null) {
                                final timeStr = DateFormat('HH:mm').format(log.createdAt);
                                formattedDateTime = '${DateFormat('dd MMM yyyy', 'id_ID').format(parsedDate)}, $timeStr';
                              } else {
                                formattedDateTime = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(log.createdAt);
                              }
                            } catch (_) {}

                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isOut ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      color: iconColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.catatan != null && log.catatan!.isNotEmpty
                                              ? log.catatan!
                                              : (isOut ? 'Stok Keluar' : 'Stok Masuk'),
                                          style: AppTypography.titleMedium.copyWith(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          formattedDateTime,
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$signPrefix${log.qty.abs()} pcs',
                                          style: AppTypography.labelLarge.copyWith(
                                            color: badgeTextColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5.sp,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Sisa: ',
                                            style: AppTypography.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: 11.sp,
                                            ),
                                          ),
                                          Text(
                                            runningBalanceMap.containsKey(log.id)
                                                ? '${runningBalanceMap[log.id]} pcs'
                                                : '-',
                                            style: AppTypography.bodySmall.copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
