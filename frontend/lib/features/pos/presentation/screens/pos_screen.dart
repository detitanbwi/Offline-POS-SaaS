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
import '../../../printer/application/printer_notifier.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../table/application/table_notifier.dart';
import 'payment_screen.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../core/utils/pdf_receipt_generator.dart';
import '../../../../core/widgets/app_receipt_preview_modal.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/di/providers.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _customerNameController = TextEditingController();
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

      final existingCustomerName = ref.read(orderNotifierProvider).customerName;
      if (existingCustomerName != null) {
        _customerNameController.text = existingCustomerName;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
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
    final isTakeAway = orderState.isTakeAway;
    final customerName = orderState.customerName;

    String subtitleText = '';
    if (isTakeAway) {
      subtitleText = customerName != null && customerName.isNotEmpty
          ? '🥡 Take Away ($customerName)'
          : '🥡 Take Away (Tanpa Meja)';
    } else if (tableName.isNotEmpty) {
      subtitleText = customerName != null && customerName.isNotEmpty
          ? '🍽️ $tableName ($customerName)'
          : '🍽️ $tableName ($orderNumber)';
    }

    final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);

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
          toolbarHeight: isMobileLandscape ? 42 : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaksi POS', style: TextStyle(fontSize: isMobileLandscape ? 14 : 16, fontWeight: FontWeight.bold)),
              if (subtitleText.isNotEmpty)
                Text(
                  subtitleText,
                  style: TextStyle(fontSize: isMobileLandscape ? 10 : 12, color: Colors.white70),
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
            // Mobile Landscape Split Layout (flex 4:3 for more cart width)
            mobileLandscape: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildCatalogHeader(activeCategories),
                      Expanded(
                        child: _buildCatalogGrid(activeProducts, productState.isLoading, cartNotifier),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 3,
                  child: _buildCartPanel(context, cartState, cartNotifier),
                ),
              ],
            ),
            // Tablet Split Layout (flex 3:2 untouched)
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
                const VerticalDivider(width: 1),
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
      message: 'Apakah Anda yakin ingin keluar?',
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
    final orderState = ref.read(orderNotifierProvider);
    if (orderState.isTakeAway) {
      return true; // Take Away does not require a table
    }

    final tableState = ref.read(tableNotifierProvider);
    if (tableState.allTables.isEmpty) {
      return true;
    }

    if (orderState.selectedTable != null) {
      return true;
    }

    // Refresh active orders map to get latest database state
    await ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    if (!mounted) return false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width > 500 ? 400 : MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: Consumer(
              builder: (consumerContext, ref, child) {
                final tableState = ref.watch(tableNotifierProvider);
                final orderState = ref.watch(orderNotifierProvider);
                final allTables = tableState.allTables;
                final activeOrdersMap = orderState.activeOrdersMap;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pilih Meja Restoran',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Silakan pilih meja untuk pesanan Dine-In ini.',
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
                            onTap: () async {
                              ref.read(orderNotifierProvider.notifier).selectTable(table);
                              if (isOccupied && activeOrder != null) {
                                final products = ref.read(productNotifierProvider).allProducts;
                                final items = await ref.read(orderRepositoryProvider).getOrderItems(activeOrder.id);
                                ref.read(cartNotifierProvider.notifier).loadDraftItems(items, products);
                              }
                              Navigator.pop(dialogContext);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            ref.read(orderNotifierProvider.notifier).setOrderType('take_away');
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.takeout_dining_rounded),
                          label: const Text('Ubah ke Take Away'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Batal'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    return ref.read(orderNotifierProvider).selectedTable != null || ref.read(orderNotifierProvider).isTakeAway;
  }

  // Header catalog with search field & category selection horizontal chips
  Widget _buildCatalogHeader(List<dynamic> activeCategories) {
    final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobileLandscape ? AppSpacing.s : AppSpacing.m),
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
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.table_restaurant_rounded,
                      size: 14,
                      color: vacantCount > 0 ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sisa Meja: ',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: isMobileLandscape ? 11 : 13),
                    ),
                    Text(
                      '$vacantCount dari ${tableState.allTables.length} meja',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: vacantCount > 0 ? AppColors.success : AppColors.error,
                        fontSize: isMobileLandscape ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
          SizedBox(height: isMobileLandscape ? 4 : 10),
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
                  visualDensity: isMobileLandscape ? VisualDensity.compact : null,
                  labelStyle: TextStyle(
                    color: _selectedCategoryId == null ? Colors.white : AppColors.textSecondary,
                    fontSize: isMobileLandscape ? 11 : 13,
                  ),
                ),
                ...activeCategories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: FilterChip(
                      label: Text(cat.nama),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      visualDensity: isMobileLandscape ? VisualDensity.compact : null,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: isMobileLandscape ? 11 : 13,
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

  Widget _buildCatalogGrid(List<Product> products, bool isLoading, CartNotifier cartNotifier) {
    if (isLoading) {
      return const AppLoading(message: 'Memuat katalog produk...');
    }

    if (products.isEmpty) {
      return const AppEmptyState(
        title: 'Produk Tidak Ditemukan',
        description: 'Tidak ada produk aktif atau sesuai kriteria pencarian.',
        icon: Icons.search_off_rounded,
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);

    return GridView.builder(
      padding: EdgeInsets.all(isMobileLandscape ? AppSpacing.s : AppSpacing.m),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isMobileLandscape ? 135 : (isTablet ? 180 : 180),
        mainAxisSpacing: isMobileLandscape ? 8 : 12,
        crossAxisSpacing: isMobileLandscape ? 8 : 12,
        childAspectRatio: isMobileLandscape ? 0.85 : (isTablet && isLandscape ? 0.85 : 0.72),
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
                            style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            product.kategoriNama ?? 'Master',
                            style: AppTypography.bodySmall,
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
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

  Widget _buildOrderTypeAndCustomerSection(
    BuildContext context,
    OrderState orderState,
    OrderNotifier orderNotifier,
  ) {
    final isTakeAway = orderState.isTakeAway;
    final tableName = orderState.selectedTable?.nama;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle Order Type
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_rounded, size: 16),
                    SizedBox(width: 4),
                    Text('Dine-In'),
                  ],
                ),
                selected: !isTakeAway,
                onSelected: (selected) {
                  if (selected) {
                    orderNotifier.setOrderType('dine_in');
                  }
                },
                selectedColor: AppColors.primaryContainer,
                labelStyle: TextStyle(
                  color: !isTakeAway ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: !isTakeAway ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.takeout_dining_rounded, size: 16),
                    SizedBox(width: 4),
                    Text('Take Away'),
                  ],
                ),
                selected: isTakeAway,
                onSelected: (selected) {
                  if (selected) {
                    orderNotifier.setOrderType('take_away');
                  }
                },
                selectedColor: Colors.orange.shade100,
                labelStyle: TextStyle(
                  color: isTakeAway ? Colors.orange.shade900 : AppColors.textSecondary,
                  fontWeight: isTakeAway ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!isTakeAway) ...[
          if (tableName != null) ...[
            Row(
              children: [
                const Icon(Icons.table_restaurant_rounded, size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text('Meja: ', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                Text(
                  tableName,
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                Text(
                  ' (${orderState.activeOrder?.nomorOrder ?? 'Order Baru'})',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primary),
                  onPressed: () => _ensureTableSelected(),
                  tooltip: 'Ganti Meja',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => _ensureTableSelected(),
              icon: const Icon(Icons.table_restaurant_rounded, size: 16),
              label: const Text('Pilih Meja Restoran'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.takeout_dining_rounded, size: 16, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pesanan Bungkus / Take Away (Tanpa Meja)',
                    style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Atas Nama (Customer Name) Field
        TextField(
          controller: _customerNameController,
          onChanged: (val) => orderNotifier.setCustomerName(val),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Atas Nama / Nama Customer (Opsional)',
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // Tablet Side-by-side Cart Panel
  Widget _buildCartPanel(BuildContext context, CartState state, CartNotifier cartNotifier) {
    final orderState = ref.watch(orderNotifierProvider);
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobileLandscape ? AppSpacing.s : AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Keranjang Belanja',
                  style: AppTypography.titleMedium.copyWith(fontSize: isMobileLandscape ? 14 : 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppColors.error),
                onPressed: state.items.isEmpty ? null : () => cartNotifier.clear(),
                tooltip: 'Kosongkan Keranjang',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildOrderTypeAndCustomerSection(context, orderState, orderNotifier),
          const Divider(height: 12),
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
          const Divider(height: 12),
          // Scrollable Action Area for landscape overflow protection
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBillSummary(state),
                  const SizedBox(height: 8),
                  if (isMobileLandscape) ...[
                    // Side-by-side action buttons for mobile landscape to save vertical height
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Bayar',
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
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AppButton(
                            text: 'Ke Dapur',
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
                          ),
                        ),
                      ],
                    ),
                    if (orderState.activeOrder != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: 'Cetak Bil',
                              type: AppButtonType.secondary,
                              onPressed: _handlePrintBill,
                              icon: Icons.print_rounded,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppButton(
                              text: 'Batal',
                              type: AppButtonType.destructive,
                              onPressed: () => _handleCancelOrder(context),
                              icon: Icons.cancel_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    // Standard full-width stacked action buttons for Tablet
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
                    if (orderState.activeOrder != null) ...[
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
                        text: 'Batalkan Pesanan',
                        type: AppButtonType.destructive,
                        onPressed: () => _handleCancelOrder(context),
                        icon: Icons.cancel_outlined,
                        width: double.infinity,
                      ),
                    ],
                  ],
                ],
              ),
            ),
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
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(CurrencyFormatter.format(state.subtotal), style: AppTypography.bodyLarge),
              ),
            ),
          ],
        ),
        if (state.taxRate > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pajak (PPN ${state.taxRate.toStringAsFixed(0)}%)',
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(CurrencyFormatter.format(state.taxAmount), style: AppTypography.bodyLarge),
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 16, thickness: 1.5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Bayar', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyFormatter.format(state.grandTotal),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
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
                              final orderState = ref.watch(orderNotifierProvider);
                              final orderNotifier = ref.read(orderNotifierProvider.notifier);

                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.m),
                                  child: ListView(
                                    controller: scrollController,
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
                                      _buildOrderTypeAndCustomerSection(context, orderState, orderNotifier),
                                      const Divider(),
                                      if (cState.items.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(24),
                                          child: Center(child: Text('Keranjang Kosong')),
                                        )
                                      else
                                        ...cState.items.map(
                                          (item) => Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _CartItemRow(
                                                item: item,
                                                cartNotifier: cNotifier,
                                                onNoteTap: () => _showNoteDialog(rootContext, item),
                                              ),
                                              const Divider(),
                                            ],
                                          ),
                                        ),
                                      _buildBillSummary(cState),
                                      const SizedBox(height: 16),
                                      if (ResponsiveLayout.isMobileLandscape(context)) ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: AppButton(
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
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: AppButton(
                                                text: 'Simpan Order',
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
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
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
    final isTakeAway = orderState.isTakeAway;
    final labelName = isTakeAway ? 'Take Away' : (selectedTable?.nama ?? 'Meja');

    final printedItems = await orderNotifier.saveCurrentOrderDraft(
      cartState.items,
      cartState.subtotal,
      cartState.taxRate,
      cartState.taxAmount,
      cartState.grandTotal,
      customerName: orderState.customerName,
    );

    if (!context.mounted) return;
    if (printedItems != null) {
      cartNotifier.clear();
      final savedOrderHeader = ref.read(orderNotifierProvider).activeOrder;

      AppSnackbar.showSuccess(context, 'Pesanan $labelName berhasil disimpan & dikirim ke dapur.');

      if (printedItems.isNotEmpty && savedOrderHeader != null) {
        // Show Kitchen Ticket Preview & Printing Modal
        final printerState = ref.read(printerNotifierProvider);
        final kitchenPrinterList = printerState.configuredPrinters.where((p) => p.isKitchen).toList();
        final kitchenPrinter = kitchenPrinterList.isNotEmpty ? kitchenPrinterList.first : null;

        final activeUser = ref.read(authSessionProvider);
        final batchCount = await ref.read(orderRepositoryProvider).getBatchCount(savedOrderHeader.id);
        final waveInfo = batchCount <= 1 ? '#1 (Baru)' : '#$batchCount (Tambahan)';

        final textPreview = await ReceiptGenerator.formatKitchenTextPreview(
          order: savedOrderHeader,
          itemsToPrint: printedItems,
          cashierNama: activeUser?.nama,
          waveInfo: waveInfo,
          charsPerLine: kitchenPrinter?.effectiveCharsPerLine ?? 32,
        );

        if (!context.mounted) return;
        AppReceiptPreviewModal.show(
          context,
          title: 'Struk Pesanan Dapur',
          receiptTextPreview: textPreview,
          onGeneratePdf: () => PdfReceiptGenerator.generateKitchenTicketPdf(
            order: savedOrderHeader,
            itemsToPrint: printedItems,
            cashierNama: activeUser?.nama,
            waveInfo: waveInfo,
          ),
          onGenerateEscPosBytes: () => ReceiptGenerator.generateKitchenTicket(
            order: savedOrderHeader,
            itemsToPrint: printedItems,
            cashierNama: activeUser?.nama,
            waveInfo: waveInfo,
            paperSize: kitchenPrinter?.escPosPaperSize ?? PaperSize.mm58,
            charsPerLine: kitchenPrinter?.effectiveCharsPerLine ?? 32,
            autoCut: kitchenPrinter?.autoCut ?? false,
          ),
        );
      }
    } else {
      final err = ref.read(orderNotifierProvider).errorMessage;
      AppSnackbar.showError(context, err ?? 'Gagal menyimpan pesanan.');
    }
  }

  Future<void> _handleCancelOrder(BuildContext context) async {
    AppDialog.show(
      context: context,
      title: 'Batalkan Pesanan',
      message: 'Apakah Anda yakin ingin membatalkan pesanan ini?',
      confirmText: 'Batalkan Pesanan',
      isDestructive: true,
      onConfirm: () async {
        final success = await ref.read(orderNotifierProvider.notifier).cancelCurrentOrder();
        if (!context.mounted) return;
        Navigator.pop(context); // Close confirm dialog
        if (success) {
          ref.read(cartNotifierProvider.notifier).clear();
          AppSnackbar.showSuccess(context, 'Pesanan berhasil dibatalkan.');
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

    final printerState = ref.read(printerNotifierProvider);
    final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
    final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

    final activeUser = ref.read(authSessionProvider);
    final textPreview = await ReceiptGenerator.formatBillTextPreview(
      order: order,
      items: items,
      cashierNama: activeUser?.nama,
      charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
    );

    if (!mounted) return;
    AppReceiptPreviewModal.show(
      context,
      title: 'Tagihan Sementara',
      receiptTextPreview: textPreview,
      onGeneratePdf: () => PdfReceiptGenerator.generateBillPdf(
        order: order,
        items: items,
        cashierNama: activeUser?.nama,
      ),
      onGenerateEscPosBytes: () => ReceiptGenerator.generateBillReceipt(
        order: order,
        items: items,
        cashierNama: activeUser?.nama,
        paperSize: cashierPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: cashierPrinter?.autoCut ?? false,
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
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    CurrencyFormatter.format(item.subtotal),
                    style: AppTypography.titleMedium.copyWith(fontSize: 14.sp),
                  ),
                ),
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
