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
import '../../../product/domain/models/product.dart';
import '../../application/stock_notifier.dart';
import '../widgets/stock_in_form.dart';
import 'stock_product_detail_screen.dart';

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productNotifierProvider.notifier).loadProducts();
      ref.read(stockNotifierProvider.notifier).loadStockIn();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog(BuildContext context) async {
    var productState = ref.read(productNotifierProvider);
    if (productState.allProducts.isEmpty) {
      await ref.read(productNotifierProvider.notifier).loadProducts();
      productState = ref.read(productNotifierProvider);
    }

    final stockableProducts = productState.allProducts
        .where((p) => p.isActive && !p.isPackage && p.stok != -1)
        .toList();

    if (stockableProducts.isEmpty) {
      if (context.mounted) {
        AppSnackbar.showWarning(
          context,
          'Tidak ada produk dengan manajemen stok. Tambahkan atau aktifkan stok produk terlebih dahulu!',
        );
      }
      return;
    }

    final formKey = GlobalKey<StockInFormState>();

    if (!context.mounted) return;
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
            ref.read(productNotifierProvider.notifier).loadProducts();
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
    final productState = ref.watch(productNotifierProvider);
    final stockState = ref.watch(stockNotifierProvider);

    // Filter products: only active products with stock management
    final allStockableProducts = productState.allProducts
        .where((p) => p.isActive && !p.isPackage && p.stok != -1)
        .toList();

    final filteredProducts = allStockableProducts.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.kategoriNama != null && p.kategoriNama!.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kartu Stok Produk'),
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
            // Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 12),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama atau kode produk...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // Product List
            Expanded(
              child: productState.isLoading
                  ? const AppLoading(message: 'Memuat data produk...')
                  : filteredProducts.isEmpty
                      ? AppEmptyState(
                          title: _searchQuery.isNotEmpty ? 'Produk Tidak Ditemukan' : 'Belum Ada Produk',
                          description: _searchQuery.isNotEmpty
                              ? 'Tidak ada produk yang cocok dengan "$_searchQuery".'
                              : 'Tambahkan produk dengan manajemen stok aktif untuk melihat kartu stok.',
                          icon: Icons.inventory_2_outlined,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m).copyWith(bottom: 100),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final p = filteredProducts[index];
                            final mutationCount = stockState.allStockIn.where((s) => s.produkId == p.id).length;
                            final isOutOfStock = p.stok == 0;

                            return AppCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StockProductDetailScreen(product: p),
                                  ),
                                );
                              },
                              padding: const EdgeInsets.all(14),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? AppColors.error.withValues(alpha: 0.1)
                                          : AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      color: isOutOfStock ? AppColors.error : AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.nama,
                                          style: AppTypography.titleMedium.copyWith(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$mutationCount riwayat mutasi',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? AppColors.error.withValues(alpha: 0.1)
                                          : AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isOutOfStock
                                            ? AppColors.error.withValues(alpha: 0.25)
                                            : AppColors.success.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Sisa Stok',
                                          style: AppTypography.labelSmall.copyWith(
                                            fontSize: 10.sp,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          isOutOfStock ? 'Habis' : '${p.stok} pcs',
                                          style: AppTypography.labelLarge.copyWith(
                                            color: isOutOfStock ? AppColors.error : AppColors.success,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textSecondary,
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
