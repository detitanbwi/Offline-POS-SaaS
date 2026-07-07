import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
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
import 'payment_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Pre-load products and categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productNotifierProvider.notifier).loadProducts();
      ref.read(categoryNotifierProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        .where((p) => p.nama.toLowerCase().contains(_searchController.text.toLowerCase()))
        .where((p) => _selectedCategoryId == null || p.kategoriId == _selectedCategoryId)
        .toList();

    final activeCategories = categoryState.allCategories.where((c) => c.isActive).toList();

    // Listen to cart state errors (e.g. stock warning) and display snackbar
    ref.listen(cartNotifierProvider, (previous, next) {
      if (next.errorMessage != null) {
        AppSnackbar.showWarning(context, next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kasir POS (Transaksi)'),
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
    );
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
            onChanged: (val) => setState(() {}),
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
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOutOfStock = product.stok <= 0;

        return AppCard(
          borderSide: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.all(10),
          onTap: isOutOfStock ? null : () => cartNotifier.addItem(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Product details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nama,
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.kategoriNama ?? 'Master',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              // Price and Stock level status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      CurrencyFormatter.format(product.harga),
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.secondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isOutOfStock ? AppColors.error : AppColors.success).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOutOfStock ? 'Habis' : 'Stok: ${product.stok}',
                      style: TextStyle(
                        color: isOutOfStock ? AppColors.error : AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Tablet Side-by-side Cart Panel
  Widget _buildCartPanel(BuildContext context, CartState state, CartNotifier cartNotifier) {
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
          const Divider(height: 24),
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
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PaymentScreen()),
                    );
                  },
            icon: Icons.arrow_forward_rounded,
          ),
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
    final totalQty = state.items.fold<int>(0, (prev, item) => prev + item.qty);

    return Container(
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
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => DraggableScrollableSheet(
                      initialChildSize: 0.85,
                      maxChildSize: 0.95,
                      minChildSize: 0.5,
                      builder: (context, scrollController) => Container(
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Consumer(
                          builder: (context, ref, child) {
                            final cState = ref.watch(cartNotifierProvider);
                            final cNotifier = ref.read(cartNotifierProvider.notifier);
                            return Padding(
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
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Expanded(
                                    child: ListView.separated(
                                      controller: scrollController,
                                      itemCount: cState.items.length,
                                      separatorBuilder: (_, __) => const Divider(),
                                      itemBuilder: (context, index) {
                                        final item = cState.items[index];
                                        return _CartItemRow(
                                          item: item,
                                          cartNotifier: cNotifier,
                                          onNoteTap: () => _showNoteDialog(context, item),
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
                                        : () {
                                            Navigator.pop(context); // Close bottom sheet
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const PaymentScreen()),
                                            );
                                          },
                                    icon: Icons.payment_rounded,
                                  ),
                                ],
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentScreen()),
                  );
                },
                icon: Icons.payments_outlined,
              ),
            ],
          ),
        ],
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
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(item.product.harga),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12),
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
                            fontSize: 11,
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
                style: AppTypography.titleMedium.copyWith(fontSize: 14),
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
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
                onPressed: onNoteTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 30),
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
