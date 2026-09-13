import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../application/trash_bin_notifier.dart';

enum TrashBinTab { product, category, table, paymentMethod, cashier, platform }

class TrashBinScreen extends ConsumerStatefulWidget {
  final TrashBinTab initialTab;

  const TrashBinScreen({
    super.key,
    this.initialTab = TrashBinTab.product,
  });

  @override
  ConsumerState<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends ConsumerState<TrashBinScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trashBinNotifierProvider.notifier).loadAll();
    });
  }

  void _confirmPermanentDelete({
    required BuildContext context,
    required String itemName,
    required Future<bool> Function() onConfirm,
  }) {
    AppDialog.showConfirmDelete(
      context: context,
      title: 'Hapus Permanen?',
      itemName: itemName,
      onDelete: () async {
        Navigator.pop(context);
        final ok = await onConfirm();
        if (!context.mounted) return;
        final state = ref.read(trashBinNotifierProvider);
        if (ok) {
          if (state.successMessage != null) {
            AppSnackbar.showSuccess(context, state.successMessage!);
          }
        } else {
          if (state.errorMessage != null) {
            AppSnackbar.showError(context, state.errorMessage!);
          }
        }
      },
    );
  }

  void _handleRestore({
    required BuildContext context,
    required Future<bool> Function() onRestore,
  }) async {
    final ok = await onRestore();
    if (!context.mounted) return;
    final state = ref.read(trashBinNotifierProvider);
    if (ok) {
      if (state.successMessage != null) {
        AppSnackbar.showSuccess(context, state.successMessage!);
      }
    } else {
      if (state.errorMessage != null) {
        AppSnackbar.showError(context, state.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trashBinNotifierProvider);
    final notifier = ref.read(trashBinNotifierProvider.notifier);

    return DefaultTabController(
      length: 6,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(
            'Tempat Sampah',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.normal,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            tabs: [
              Tab(text: 'Produk (${state.deletedProducts.length})'),
              Tab(text: 'Kategori (${state.deletedCategories.length})'),
              Tab(text: 'Meja (${state.deletedTables.length})'),
              Tab(text: 'Metode Bayar (${state.deletedPaymentMethods.length})'),
              Tab(text: 'Kasir (${state.deletedCashiers.length})'),
              Tab(text: 'Platform (${state.deletedPlatforms.length})'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => notifier.loadAll(),
              tooltip: 'Segarkan',
            ),
          ],
        ),
        body: Column(
          children: [
            // Info Header Banner
            Container(
              margin: const EdgeInsets.all(AppSpacing.m),
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Item di tempat sampah tidak muncul di kasir. Anda dapat memulihkannya kapan saja. Item dengan riwayat transaksi dilindungi dari hapus permanen agar laporan keuangan tetap akurat.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat data tempat sampah...')
                  : TabBarView(
                      children: [
                        // Tab 1: Produk
                        _buildProductTab(state, notifier),
                        // Tab 2: Kategori
                        _buildCategoryTab(state, notifier),
                        // Tab 3: Meja
                        _buildTableTab(state, notifier),
                        // Tab 4: Metode Bayar
                        _buildPaymentMethodTab(state, notifier),
                        // Tab 5: Kasir
                        _buildCashierTab(state, notifier),
                        // Tab 6: Platform
                        _buildPlatformTab(state, notifier),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildProductTab(TrashBinState state, TrashBinNotifier notifier) {
    if (state.deletedProducts.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Tidak Ada Produk Terhapus',
        description: 'Semua produk aktif berada di katalog produk.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: state.deletedProducts.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final prod = state.deletedProducts[index];
        return _buildTrashCard(
          title: prod.nama,
          subtitle: '${prod.kategoriNama ?? "Tanpa Kategori"} • ${CurrencyFormatter.format(prod.harga)}',
          deletedDate: prod.updatedAt,
          leadingIcon: Icons.fastfood_outlined,
          onRestore: () => _handleRestore(
            context: context,
            onRestore: () => notifier.restoreProduct(prod.id),
          ),
          onPermanentDelete: () => _confirmPermanentDelete(
            context: context,
            itemName: prod.nama,
            onConfirm: () => notifier.permanentDeleteProduct(prod.id),
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(TrashBinState state, TrashBinNotifier notifier) {
    if (state.deletedCategories.isEmpty) {
      return const AppEmptyState(
        icon: Icons.category_outlined,
        title: 'Tidak Ada Kategori Terhapus',
        description: 'Semua kategori aktif berada di menu kategori.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: state.deletedCategories.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final cat = state.deletedCategories[index];
        return _buildTrashCard(
          title: cat.nama,
          subtitle: 'Kategori Produk',
          deletedDate: cat.updatedAt,
          leadingIcon: Icons.category_outlined,
          onRestore: () => _handleRestore(
            context: context,
            onRestore: () => notifier.restoreCategory(cat.id),
          ),
          onPermanentDelete: () => _confirmPermanentDelete(
            context: context,
            itemName: cat.nama,
            onConfirm: () => notifier.permanentDeleteCategory(cat.id),
          ),
        );
      },
    );
  }

  Widget _buildTableTab(TrashBinState state, TrashBinNotifier notifier) {
    if (state.deletedTables.isEmpty) {
      return const AppEmptyState(
        icon: Icons.table_restaurant_outlined,
        title: 'Tidak Ada Meja Terhapus',
        description: 'Semua meja aktif berada di tata letak meja.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: state.deletedTables.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final table = state.deletedTables[index];
        return _buildTrashCard(
          title: table.nama,
          subtitle: 'Nomor: ${table.nomor}',
          deletedDate: table.deletedAt ?? table.updatedAt,
          leadingIcon: Icons.table_restaurant_outlined,
          onRestore: () => _handleRestore(
            context: context,
            onRestore: () => notifier.restoreTable(table.id),
          ),
          onPermanentDelete: () => _confirmPermanentDelete(
            context: context,
            itemName: table.nama,
            onConfirm: () => notifier.permanentDeleteTable(table.id),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodTab(TrashBinState state, TrashBinNotifier notifier) {
    if (state.deletedPaymentMethods.isEmpty) {
      return const AppEmptyState(
        icon: Icons.payments_outlined,
        title: 'Tidak Ada Metode Bayar Terhapus',
        description: 'Semua metode pembayaran aktif berada di menu pembayaran.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: state.deletedPaymentMethods.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final pm = state.deletedPaymentMethods[index];
        return _buildTrashCard(
          title: pm.nama,
          subtitle: 'Metode Pembayaran',
          deletedDate: pm.deletedAt ?? pm.updatedAt,
          leadingIcon: pm.iconData,
          onRestore: () => _handleRestore(
            context: context,
            onRestore: () => notifier.restorePaymentMethod(pm.id),
          ),
          onPermanentDelete: () => _confirmPermanentDelete(
            context: context,
            itemName: pm.nama,
            onConfirm: () => notifier.permanentDeletePaymentMethod(pm.id),
          ),
        );
      },
    );
  }

  Widget _buildCashierTab(TrashBinState state, TrashBinNotifier notifier) {
    if (state.deletedCashiers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        title: 'Tidak Ada Kasir Terhapus',
        description: 'Semua akun kasir aktif berada di menu kasir.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: state.deletedCashiers.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final cashier = state.deletedCashiers[index];
        return _buildTrashCard(
          title: cashier.nama,
          subtitle: 'Username: ${cashier.username}',
          deletedDate: cashier.updatedAt,
          leadingIcon: Icons.badge_outlined,
          onRestore: () => _handleRestore(
            context: context,
            onRestore: () => notifier.restoreCashier(cashier.id),
          ),
          onPermanentDelete: () => _confirmPermanentDelete(
            context: context,
            itemName: cashier.nama,
            onConfirm: () => notifier.permanentDeleteCashier(cashier.id),
          ),
        );
      },
    );
  }

  Widget _buildPlatformTab(TrashBinState state, TrashBinNotifier notifier) {
    if (state.deletedPlatforms.isEmpty) {
      return const AppEmptyState(
        icon: Icons.delivery_dining_outlined,
        title: 'Tidak Ada Platform Terhapus',
        description: 'Semua platform online aktif berada di menu platform.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: state.deletedPlatforms.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final platform = state.deletedPlatforms[index];
        return _buildTrashCard(
          title: platform.nama,
          subtitle: 'Platform Pesanan Online',
          deletedDate: platform.updatedAt,
          leadingIcon: Icons.delivery_dining_outlined,
          onRestore: () => _handleRestore(
            context: context,
            onRestore: () => notifier.restorePlatform(platform.id),
          ),
          onPermanentDelete: () => _confirmPermanentDelete(
            context: context,
            itemName: platform.nama,
            onConfirm: () => notifier.permanentDeletePlatform(platform.id),
          ),
        );
      },
    );
  }

  Widget _buildTrashCard({
    required String title,
    required String subtitle,
    required DateTime? deletedDate,
    required IconData leadingIcon,
    required VoidCallback onRestore,
    required VoidCallback onPermanentDelete,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderSide: const BorderSide(color: AppColors.divider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.disabled.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, color: AppColors.textSecondary, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    if (deletedDate != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Dihapus: ${_dateFormat.format(deletedDate)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error.withValues(alpha: 0.8),
                          fontSize: 11.sp,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          const Divider(height: 1, color: AppColors.divider),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onPermanentDelete,
                icon: Icon(Icons.delete_forever_rounded, size: 16.sp, color: AppColors.error),
                label: Text(
                  'Hapus Permanen',
                  style: TextStyle(color: AppColors.error, fontSize: 12.sp),
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton.icon(
                onPressed: onRestore,
                icon: Icon(Icons.restore_from_trash_rounded, size: 16.sp),
                label: Text(
                  'Pulihkan',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
