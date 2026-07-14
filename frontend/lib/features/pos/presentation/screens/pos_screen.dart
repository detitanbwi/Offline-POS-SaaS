import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../category/application/category_notifier.dart';
import '../../../product/application/product_notifier.dart';
import '../../../product/domain/models/product.dart';
import '../../domain/models/cart_item.dart';
import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../../table/application/table_notifier.dart';
import '../../../table/domain/models/table.dart';
import 'payment_screen.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../core/utils/pdf_receipt_generator.dart';
import '../../../../core/widgets/app_receipt_preview_modal.dart';


class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategoryId;
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Pre-load products, categories, tables, and active orders map
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productNotifierProvider.notifier).loadProducts();
      ref.read(categoryNotifierProvider.notifier).loadCategories();
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _showNoteDialog(BuildContext context, CartItem item) {
    final noteController = TextEditingController(text: item.catatan);
    
    AppDialog.show(
      context: context,
      title: 'Catatan Item: ${item.product.nama}',
      confirmText: 'Simpan',
      content: AppTextField(
        controller: noteController,
        labelText: 'Catatan tambahan',
        hintText: 'Contoh: Pedas, tanpa kecap',
        prefixIcon: Icons.edit_note_rounded,
      ),
      onConfirm: () {
        ref.read(cartNotifierProvider.notifier).updateCatatan(item.product.id, noteController.text);
        Navigator.pop(context);
        AppSnackbar.showSuccess(context, 'Catatan item berhasil diperbarui.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productNotifierProvider);
    final categoryState = ref.watch(categoryNotifierProvider);
    final cartState = ref.watch(cartNotifierProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    
    // Filter active items for checkout grid
    final activeProducts = productState.allProducts
        .where((p) => p.isActive)
        .where((p) => p.nama.toLowerCase().contains(_searchQuery.toLowerCase()))
        .where((p) => _selectedCategoryId == null || p.kategoriId == _selectedCategoryId)
        .toList();

    final activeCategories = categoryState.allCategories.where((c) => c.isActive).toList();

    // Listen to cart state errors (e.g. stock warning) and display snackbar
    ref.listen(cartNotifierProvider, (previous, next) {
      if (next.errorMessage != null) {
        AppSnackbar.showWarning(context, next.errorMessage!);
      }
    });

    final orderState = ref.watch(orderNotifierProvider);
    final tableName = orderState.selectedTable?.nama ?? '';
    final orderNumber = orderState.activeOrder?.nomorOrder ?? 'Order Baru';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaksi POS', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              if (tableName.isNotEmpty)
                Text(
                  '$tableName ($orderNumber)',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                ),
            ],
          ),
        ),
        body: SafeArea(
          child: ResponsiveLayout(
            // Mobile Portrait Layout
            mobile: Stack(
              children: [
                Column(
                  children: [
                    _buildCatalogHeader(activeCategories),
                    Expanded(
                      child: _buildCatalogGrid(activeProducts, productState.isLoading, cartNotifier),
                    ),
                    const SizedBox(height: 72), // Spacing for bottom cart floating bar
                  ],
                ),
                if (cartState.items.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildMobileCartBar(context, cartState),
                  ),
              ],
            ),
            // Tablet / Landscape Split Layout
            tablet: Row(
              children: [
                // Left side: Catalog
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildCatalogHeader(activeCategories),
                      Expanded(
                        child: _buildCatalogGrid(activeProducts, productState.isLoading, cartNotifier),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(),
                // Right side: Shopping Cart Panel
                Expanded(
                  flex: 2,
                  child: _buildCartPanel(context, cartState, cartNotifier),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    bool result = false;
    await AppDialog.show(
      context: context,
      title: 'Keluar Transaksi POS',
      message: 'Apakah Anda yakin ingin keluar?.',
      confirmText: 'Keluar',
      cancelText: 'Batal',
      isDestructive: true,
      onConfirm: () {
        result = true;
        Navigator.pop(context);
      },
    );
    return result;
  }

  Future<bool> _ensureTableSelected() async {
    final tableState = ref.read(tableNotifierProvider);
    if (tableState.allTables.isEmpty) {
      return true;
    }

    final orderState = ref.read(orderNotifierProvider);
    if (orderState.selectedTable != null) {
      return true;
    }

    // Refresh active orders map to get latest database state
    await ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    if (!mounted) return false;

    final allTables = tableState.allTables;
    final activeOrdersMap = ref.read(orderNotifierProvider).activeOrdersMap;

    TableModel? selectedTable;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width > 500 ? 400 : MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pilih Meja Restoran',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Silakan pilih meja untuk pesanan atau pembayaran ini.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: allTables.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final table = allTables[index];
                      final isOccupied = table.status == 1;
                      final activeOrder = activeOrdersMap[table.id];

                      return ListTile(
                        leading: Icon(
                          Icons.table_restaurant_rounded,
                          color: isOccupied ? AppColors.secondary : AppColors.success,
                        ),
                        title: Text(table.nama),
                        subtitle: Text(
                          isOccupied
                              ? 'Terisi (${activeOrder?.nomorOrder ?? 'Pesanan Aktif'})'
                              : 'Kosong - Nomor: ${table.nomor}',
                          style: TextStyle(
                            color: isOccupied ? AppColors.secondary : AppColors.success,
                            fontWeight: isOccupied ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onTap: () {
                          selectedTable = table;
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedTable != null) {
      await ref.read(orderNotifierProvider.notifier).selectTable(selectedTable);
      final updatedOrderState = ref.read(orderNotifierProvider);
      if (updatedOrderState.activeOrderItems.isNotEmpty) {
        final products = ref.read(productNotifierProvider).allProducts;
        ref.read(cartNotifierProvider.notifier).loadDraftItems(updatedOrderState.activeOrderItems, products);
      }
      return true;
    }
    return false;
  }

  // Header catalog with search field & category selection horizontal chips
  Widget _buildCatalogHeader(List<dynamic> activeCategories) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _searchController,
            labelText: 'Cari Produk POS',
            prefixIcon: Icons.search_rounded,
            onChanged: (val) {
              if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                setState(() {
                  _searchQuery = val;
                });
              });
            },
          ),
          Builder(
            builder: (context) {
              final tableState = ref.watch(tableNotifierProvider);
              final vacantCount = tableState.allTables.where((t) => t.isEmpty).length;
              if (tableState.allTables.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.table_restaurant_rounded,
                      size: 16,
                      color: vacantCount > 0 ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sisa Meja Tersedia: ',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    Text(
                      '$vacantCount dari ${tableState.allTables.length} meja',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: vacantCount > 0 ? AppColors.success : AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: _selectedCategoryId == null,
                  onSelected: (_) => setState(() => _selectedCategoryId = null),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _selectedCategoryId == null ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                ...activeCategories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: FilterChip(
                      label: Text(cat.nama),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Grid list of products matching searches/categories
  Widget _buildCatalogGrid(List<Product> products, bool loading, CartNotifier cartNotifier) {
    if (loading) {
      return const AppLoading(message: 'Memuat produk kasir...');
    }

    if (products.isEmpty) {
      return const AppEmptyState(
        title: 'Produk Tidak Ditemukan',
        description: 'Tidak ada produk aktif atau sesuai kriteria pencarian.',
        icon: Icons.search_off_rounded,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.m),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOutOfStock = product.stok != -1 && product.stok <= 0;

        return AppCard(
          borderSide: const BorderSide(color: AppColors.divider),
          padding: EdgeInsets.zero,
          onTap: isOutOfStock ? null : () => cartNotifier.addItem(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: product.image != null && product.image!.isNotEmpty
                        ? (Validators.isValidWebUrl(product.image!)
                            ? Image.network(
                                product.image!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 28),
                                ),
                              )
                            : Validators.isValidLocalFile(product.image!)
                                ? Image.file(
                                    File(product.image!),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 28),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.fastfood_rounded, color: AppColors.textSecondary, size: 36),
                                  ))
                        : const Center(
                            child: Icon(Icons.fastfood_rounded, color: AppColors.textSecondary, size: 36),
                          ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.nama,
                            style: AppTypography.titleMedium.copyWith(fontSize: 13.sp, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            product.kategoriNama ?? 'Master',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              CurrencyFormatter.format(product.harga),
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // overflow
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (isOutOfStock ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOutOfStock ? 'Habis' : (product.stok == -1 ? 'Stok: ∞' : 'Stok: ${product.stok}'),
                              style: TextStyle(
                                color: isOutOfStock ? AppColors.error : AppColors.success,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Tablet Side-by-side Cart Panel
  Widget _buildCartPanel(BuildContext context, CartState state, CartNotifier cartNotifier) {
    final tableState = ref.watch(tableNotifierProvider);
    final orderState = ref.watch(orderNotifierProvider);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Keranjang Belanja', style: AppTypography.titleMedium.copyWith(fontSize: 18)),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.error),
                label: const Text('Kosongkan', style: TextStyle(color: AppColors.error)),
                onPressed: state.items.isEmpty ? null : () => cartNotifier.clear(),
              ),
            ],
          ),
          if (tableState.allTables.isNotEmpty) ...[
            if (orderState.selectedTable != null) ...[
              Row(
                children: [
                  const Icon(Icons.table_restaurant_rounded, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'Meja: ',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    orderState.selectedTable!.nama,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  Text(
                    ' (${orderState.activeOrder?.nomorOrder ?? 'Order Baru'})',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                    onPressed: () async {
                      ref.read(orderNotifierProvider.notifier).selectTable(null);
                      await _ensureTableSelected();
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const Divider(height: 24),
            ] else ...[
              OutlinedButton.icon(
                onPressed: () => _ensureTableSelected(),
                icon: const Icon(Icons.table_restaurant_rounded, size: 16),
                label: const Text('Pilih Meja Restoran'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Divider(height: 24),
            ],
          ],
          // Cart Items List
          Expanded(
            child: state.items.isEmpty
                ? const AppEmptyState(
                    title: 'Keranjang Kosong',
                    description: 'Silakan pilih produk katalog untuk ditambahkan ke transaksi.',
                    icon: Icons.shopping_basket_outlined,
                  )
                : ListView.separated(
                    itemCount: state.items.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _CartItemRow(
                        item: item,
                        cartNotifier: cartNotifier,
                        onNoteTap: () => _showNoteDialog(context, item),
                      );
                    },
                  ),
          ),
          const Divider(height: 24),
          // Subtotal/Tax/Grand Total calculations
          _buildBillSummary(state),
          const SizedBox(height: 16),
          // Checkout Proceed Button
          AppButton(
            text: 'Lanjutkan ke Pembayaran',
            onPressed: state.items.isEmpty
                ? null
                : () async {
                    if (await _ensureTableSelected()) {
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentScreen()),
                      );
                    }
                  },
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 8),
          AppButton(
            text: 'Simpan Order (Kirim ke Dapur)',
            type: AppButtonType.secondary,
            onPressed: state.items.isEmpty
                ? null
                : () async {
                    if (await _ensureTableSelected()) {
                      if (!context.mounted) return;
                      _handleSaveOrderDraft(context, state);
                    }
                  },
            icon: Icons.kitchen_rounded,
            width: double.infinity,
          ),
          if (ref.watch(orderNotifierProvider).activeOrder != null) ...[
            const SizedBox(height: 8),
            AppButton(
              text: 'Cetak Bil (Tagihan Sementara)',
              type: AppButtonType.secondary,
              onPressed: _handlePrintBill,
              icon: Icons.print_rounded,
              width: double.infinity,
            ),
            const SizedBox(height: 8),
            AppButton(
              text: 'Batalkan Pesanan Meja',
              type: AppButtonType.destructive,
              onPressed: () => _handleCancelOrder(context),
              icon: Icons.cancel_outlined,
              width: double.infinity,
            ),
          ],
        ],
      ),
    );
  }

  // Invoice calculations helper
  Widget _buildBillSummary(CartState state) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Subtotal', style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
            Text(CurrencyFormatter.format(state.subtotal), style: AppTypography.bodyLarge),
          ],
        ),
        if (state.taxRate > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pajak (PPN ${state.taxRate.toStringAsFixed(0)}%)',
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
              Text(CurrencyFormatter.format(state.taxAmount), style: AppTypography.bodyLarge),
            ],
          ),
        ],
        const Divider(height: 24, thickness: 1.5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Bayar', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
            Text(
              CurrencyFormatter.format(state.grandTotal),
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Mobile Bottom Cart Summary Float bar
  Widget _buildMobileCartBar(BuildContext context, CartState state) {
    final rootContext = this.context;
    final totalQty = state.items.fold<int>(0, (prev, item) => prev + item.qty);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$totalQty Item Terpilih', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                Text(
                  CurrencyFormatter.format(state.grandTotal),
                  style: AppTypography.titleLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              children: [
                // Expand view cart button
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 28),
                  onPressed: () {
                    showModalBottomSheet(
                      context: rootContext,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) => DraggableScrollableSheet(
                        initialChildSize: 0.85,
                        maxChildSize: 0.95,
                        minChildSize: 0.5,
                        builder: (sheetContext2, scrollController) => Container(
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: Consumer(
                            builder: (consumerContext, ref, child) {
                              final cState = ref.watch(cartNotifierProvider);
                              final cNotifier = ref.read(cartNotifierProvider.notifier);
                              final tableState = ref.watch(tableNotifierProvider);
                              final orderState = ref.watch(orderNotifierProvider);
                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.m),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Detail Keranjang', style: AppTypography.titleLarge),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () => Navigator.of(sheetContext).pop(),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      if (tableState.allTables.isNotEmpty) ...[
                                        if (orderState.selectedTable != null) ...[
                                          Row(
                                            children: [
                                              const Icon(Icons.table_restaurant_rounded, size: 16, color: AppColors.secondary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Meja: ',
                                                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                              ),
                                              Text(
                                                orderState.selectedTable!.nama,
                                                style: AppTypography.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                              Text(
                                                ' (${orderState.activeOrder?.nomorOrder ?? 'Order Baru'})',
                                                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                                              ),
                                              const Spacer(),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                                onPressed: () async {
                                                  Navigator.of(sheetContext).pop();
                                                  ref.read(orderNotifierProvider.notifier).selectTable(null);
                                                  await _ensureTableSelected();
                                                },
                                                constraints: const BoxConstraints(),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                        ] else ...[
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              Navigator.of(sheetContext).pop();
                                              await _ensureTableSelected();
                                            },
                                            icon: const Icon(Icons.table_restaurant_rounded, size: 16),
                                            label: const Text('Pilih Meja Restoran'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.secondary,
                                              side: const BorderSide(color: AppColors.secondary),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                          const Divider(),
                                        ],
                                      ],
                                      Expanded(
                                        child: ListView.separated(
                                          controller: scrollController,
                                          itemCount: cState.items.length,
                                          separatorBuilder: (_, _) => const Divider(),
                                          itemBuilder: (context, index) {
                                            final item = cState.items[index];
                                            return _CartItemRow(
                                              item: item,
                                              cartNotifier: cNotifier,
                                              onNoteTap: () => _showNoteDialog(rootContext, item),
                                            );
                                          },
                                        ),
                                      ),
                                      const Divider(),
                                      _buildBillSummary(cState),
                                      const SizedBox(height: 16),
                                      AppButton(
                                        text: 'Bayar Sekarang',
                                        onPressed: cState.items.isEmpty
                                            ? null
                                            : () async {
                                                Navigator.of(sheetContext).pop();
                                                if (await _ensureTableSelected()) {
                                                  if (!mounted) return;
                                                  Navigator.of(rootContext).push(
                                                    MaterialPageRoute(builder: (_) => const PaymentScreen()),
                                                  );
                                                }
                                              },
                                        icon: Icons.payment_rounded,
                                        width: double.infinity,
                                      ),
                                      const SizedBox(height: 8),
                                      AppButton(
                                        text: 'Simpan Order (Kirim ke Dapur)',
                                        type: AppButtonType.secondary,
                                        onPressed: cState.items.isEmpty
                                            ? null
                                            : () async {
                                                Navigator.of(sheetContext).pop();
                                                if (await _ensureTableSelected()) {
                                                  if (!mounted) return;
                                                  _handleSaveOrderDraft(rootContext, cState);
                                                }
                                              },
                                        icon: Icons.kitchen_rounded,
                                        width: double.infinity,
                                      ),
                                      if (ref.watch(orderNotifierProvider).activeOrder != null) ...[
                                        const SizedBox(height: 8),
                                        AppButton(
                                          text: 'Batalkan Pesanan Meja',
                                          type: AppButtonType.destructive,
                                          onPressed: () {
                                            Navigator.of(sheetContext).pop();
                                            _handleCancelOrder(rootContext);
                                          },
                                          icon: Icons.cancel_outlined,
                                          width: double.infinity,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                AppButton(
                  text: 'Bayar',
                  onPressed: () async {
                    if (await _ensureTableSelected()) {
                      if (!mounted) return;
                      Navigator.of(rootContext).push(
                        MaterialPageRoute(builder: (_) => const PaymentScreen()),
                      );
                    }
                  },
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveOrderDraft(BuildContext context, CartState cartState) async {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final orderState = ref.read(orderNotifierProvider);

    final selectedTable = orderState.selectedTable;
    final tableName = selectedTable?.nama ?? 'Meja';
    final orderId = orderState.activeOrder?.id ?? const Uuid().v4();

    final orderHeader = OrderModel(
      id: orderId,
      nomorOrder: orderState.activeOrder?.nomorOrder ?? 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tableId: selectedTable?.id ?? '',
      tableNama: selectedTable?.nama,
      tableNomor: selectedTable?.nomor,
      subtotal: cartState.subtotal,
      taxPercentage: cartState.taxRate,
      taxAmount: cartState.taxAmount,
      grandTotal: cartState.grandTotal,
      createdAt: orderState.activeOrder?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final List<OrderItemModel> itemsToPrint = cartState.items.map((cartItem) {
      return OrderItemModel(
        id: const Uuid().v4(),
        orderId: orderHeader.id,
        produkId: cartItem.product.id,
        produkNama: cartItem.product.nama,
        produkHarga: cartItem.product.harga,
        qty: cartItem.qty,
        subtotal: cartItem.subtotal,
        catatan: cartItem.catatan,
        statusCetak: 0,
      );
    }).toList();

    final success = await orderNotifier.saveCurrentOrderDraft(
      cartState.items,
      cartState.subtotal,
      cartState.taxRate,
      cartState.taxAmount,
      cartState.grandTotal,
    );

    if (!context.mounted) return;
    if (success) {
      cartNotifier.clear();
      ref.read(orderNotifierProvider.notifier).clearActiveOrder();
      AppSnackbar.showSuccess(context, 'Pesanan $tableName berhasil disimpan & dikirim ke dapur.');

      // Show Kitchen Ticket Preview & Printing Modal
      final textPreview = await ReceiptGenerator.formatKitchenTextPreview(
        order: orderHeader,
        itemsToPrint: itemsToPrint,
      );

      if (!context.mounted) return;
      AppReceiptPreviewModal.show(
        context,
        title: 'Struk Pesanan Dapur',
        receiptTextPreview: textPreview,
        onGeneratePdf: () => PdfReceiptGenerator.generateKitchenTicketPdf(
          order: orderHeader,
          itemsToPrint: itemsToPrint,
        ),
        onGenerateEscPosBytes: () => ReceiptGenerator.generateKitchenTicket(
          order: orderHeader,
          itemsToPrint: itemsToPrint,
        ),
      );
    } else {
      final err = ref.read(orderNotifierProvider).errorMessage;
      AppSnackbar.showError(context, err ?? 'Gagal menyimpan pesanan.');
    }
  }

  Future<void> _handleCancelOrder(BuildContext context) async {
    AppDialog.show(
      context: context,
      title: 'Batalkan Pesanan',
      message: 'Apakah Anda yakin ingin membatalkan pesanan meja ini dan mengosongkan meja kembali?',
      confirmText: 'Batalkan Pesanan',
      isDestructive: true,
      onConfirm: () async {
        final success = await ref.read(orderNotifierProvider.notifier).cancelCurrentOrder();
        if (!context.mounted) return;
        Navigator.pop(context); // Close confirm dialog
        if (success) {
          ref.read(cartNotifierProvider.notifier).clear();
          AppSnackbar.showSuccess(context, 'Pesanan dibatalkan & meja dikosongkan.');
          Navigator.pop(context); // Go back to Table Selector
        } else {
          final err = ref.read(orderNotifierProvider).errorMessage;
          AppSnackbar.showError(context, err ?? 'Gagal membatalkan pesanan.');
        }
      },
    );
  }

  Future<void> _handlePrintBill() async {
    final orderState = ref.read(orderNotifierProvider);
    final order = orderState.activeOrder;
    final items = orderState.activeOrderItems;
    if (order == null) return;

    final textPreview = await ReceiptGenerator.formatBillTextPreview(
      order: order,
      items: items,
    );

    if (!mounted) return;
    AppReceiptPreviewModal.show(
      context,
      title: 'Tagihan Sementara',
      receiptTextPreview: textPreview,
      onGeneratePdf: () => PdfReceiptGenerator.generateBillPdf(
        order: order,
        items: items,
      ),
      onGenerateEscPosBytes: () => ReceiptGenerator.generateBillReceipt(
        order: order,
        items: items,
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final CartNotifier cartNotifier;
  final VoidCallback onNoteTap;

  const _CartItemRow({
    required this.item,
    required this.cartNotifier,
    required this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.nama,
                      style: AppTypography.titleMedium.copyWith(fontSize: 15.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(item.product.harga),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                    ),
                    if (item.catatan.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Catatan: ${item.catatan}',
                          style: TextStyle(
                            color: AppColors.secondaryActive,
                            fontSize: 11.sp,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Subtotal item text
              Text(
                CurrencyFormatter.format(item.subtotal),
                style: AppTypography.titleMedium.copyWith(fontSize: 14.sp),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stepper +/- buttons & note trigger button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: Icon(
                  item.catatan.isEmpty ? Icons.add_comment_outlined : Icons.comment_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(
                  item.catatan.isEmpty ? 'Tambah Catatan' : 'Ubah Catatan',
                  style: TextStyle(color: AppColors.primary, fontSize: 12.sp),
                ),
                onPressed: onNoteTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                    onPressed: () => cartNotifier.updateQuantity(item.product.id, item.qty - 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      '${item.qty}',
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onPressed: () => cartNotifier.updateQuantity(item.product.id, item.qty + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
