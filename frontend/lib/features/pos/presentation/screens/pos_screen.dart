// ignore_for_file: deprecated_member_use, use_build_context_synchronously
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
import '../../application/online_platform_notifier.dart';
import '../../../printer/application/printer_notifier.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../table/application/table_notifier.dart';
import '../../../table/domain/models/table.dart';
import '../../domain/models/order_item.dart';
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
      ref.read(onlinePlatformNotifierProvider.notifier).loadPlatforms();

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
            // Mobile Landscape Layout (Full Width Catalog + Floating Cart Bar for maximum interaction space)
            mobileLandscape: Stack(
              children: [
                Column(
                  children: [
                    _buildCatalogHeader(activeCategories),
                    Expanded(
                      child: _buildCatalogGrid(activeProducts, productState.isLoading, cartNotifier),
                    ),
                    const SizedBox(height: 64), // Spacing for floating cart bar
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width > 500 ? 440 : MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (consumerContext, ref, child) {
                final tableState = ref.watch(tableNotifierProvider);
                final orderState = ref.watch(orderNotifierProvider);
                final allTables = tableState.allTables;
                final activeOrdersMap = orderState.activeOrdersMap;
                final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pilih Meja Restoran',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Silakan pilih meja untuk pesanan Dine-In ini.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * (isMobileLandscape ? 0.38 : 0.5),
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
                              dense: isMobileLandscape,
                              leading: Icon(
                                Icons.table_restaurant_rounded,
                                color: isOccupied ? AppColors.secondary : AppColors.success,
                              ),
                              title: Text(table.nama, style: TextStyle(fontSize: isMobileLandscape ? 13 : 14)),
                              subtitle: Text(
                                isOccupied
                                    ? 'Terisi (${activeOrder?.nomorOrder ?? 'Pesanan Aktif'})'
                                    : 'Kosong - Nomor: ${table.nomor}',
                                style: TextStyle(
                                  color: isOccupied ? AppColors.secondary : AppColors.success,
                                  fontWeight: isOccupied ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              onTap: () async {
                                Navigator.pop(dialogContext);
                                if (isOccupied && activeOrder != null) {
                                  _showOccupiedTableBottomSheet(table, activeOrder);
                                } else {
                                  ref.read(orderNotifierProvider.notifier).selectTable(table);
                                  ref.read(cartNotifierProvider.notifier).clear();
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            ref.read(orderNotifierProvider.notifier).setOrderType('take_away');
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.takeout_dining_rounded, size: 18),
                          label: const Text('Ubah ke Take Away', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Batal', style: TextStyle(fontSize: 12)),
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

  Future<void> _showChangeTableDialog() async {
    final orderState = ref.read(orderNotifierProvider);
    final currentTable = orderState.selectedTable;
    final activeOrder = orderState.activeOrder;

    await ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width > 500 ? 440 : MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (consumerContext, ref, child) {
                final tableState = ref.watch(tableNotifierProvider);
                final oState = ref.watch(orderNotifierProvider);
                final allTables = tableState.allTables;
                final activeOrdersMap = oState.activeOrdersMap;
                final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);

                // Only show empty tables (except current table)
                final availableTables = allTables.where((t) {
                  if (currentTable != null && t.id == currentTable.id) return false;
                  final isOccupied = activeOrdersMap.containsKey(t.id);
                  return !isOccupied && t.status == 0;
                }).toList();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pindah Meja',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTable != null
                          ? 'Pindahkan pesanan dari ${currentTable.nama} ke meja lain.'
                          : 'Pilih meja tujuan.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (availableTables.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Tidak ada meja kosong tersedia.', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * (isMobileLandscape ? 0.38 : 0.5),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: availableTables.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final targetTable = availableTables[index];
                              return ListTile(
                                dense: isMobileLandscape,
                                leading: const Icon(Icons.table_restaurant_rounded, color: AppColors.success),
                                title: Text(targetTable.nama, style: TextStyle(fontSize: isMobileLandscape ? 13 : 14)),
                                subtitle: Text(
                                  'Kosong - Nomor: ${targetTable.nomor}',
                                  style: const TextStyle(color: AppColors.success, fontSize: 11),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onTap: () async {
                                  Navigator.pop(dialogContext);

                                  if (activeOrder != null && currentTable != null) {
                                    // Transfer existing draft order to new table
                                    await ref.read(orderRepositoryProvider).transferOrderTable(
                                      activeOrder.id,
                                      currentTable.id,
                                      targetTable.id,
                                      targetTable.nama,
                                      targetTable.nomor,
                                    );
                                    ref.read(tableNotifierProvider.notifier).loadTables();
                                    await ref.read(orderNotifierProvider.notifier).selectTable(targetTable);
                                  } else {
                                    // No active order, just switch table
                                    ref.read(orderNotifierProvider.notifier).selectTable(targetTable);
                                  }

                                  if (!mounted) return;
                                  AppSnackbar.showSuccess(
                                    context,
                                    'Pesanan dipindahkan ke ${targetTable.nama}.',
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Batal', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
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
        maxCrossAxisExtent: isMobileLandscape ? 160 : (isTablet ? 180 : 180),
        mainAxisSpacing: isMobileLandscape ? 8 : 12,
        crossAxisSpacing: isMobileLandscape ? 8 : 12,
        childAspectRatio: isMobileLandscape ? 0.9 : (isTablet && isLandscape ? 0.85 : 0.72),
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
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: isMobileLandscape ? 4 : 6),
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

  Future<void> _showOccupiedTableBottomSheet(TableModel table, dynamic activeOrder) async {
    final hasDraft = activeOrder != null;
    final repo = ref.read(orderRepositoryProvider);

    List<OrderItemModel> items = [];
    List<Map<String, dynamic>> batches = [];

    if (hasDraft) {
      items = await repo.getOrderItems(activeOrder.id);
      batches = await repo.getPrintBatches(activeOrder.id);
    }

    // Build batch mapping
    final Map<String, int> batchIndexMap = {};
    for (int i = 0; i < batches.length; i++) {
      final bId = batches[i]['id'] as String;
      batchIndexMap[bId] = i + 1;
    }

    // Group items by batch title
    final Map<String, List<OrderItemModel>> groupedItems = {};

    for (var item in items) {
      String batchTitle = 'Batch #1';
      if (item.printBatchId != null && batchIndexMap.containsKey(item.printBatchId)) {
        batchTitle = 'Batch #${batchIndexMap[item.printBatchId]}';
      } else if (item.statusCetak == 0 && batches.isNotEmpty) {
        batchTitle = 'Batch Baru (Belum Kirim Dapur)';
      }

      groupedItems.putIfAbsent(batchTitle, () => []).add(item);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rincian ${table.nama}',
                        style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (activeOrder?.customerName != null && activeOrder.customerName.isNotEmpty)
                        Text(
                          'Atas Nama: ${activeOrder.customerName}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (hasDraft ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (hasDraft ? AppColors.warning : AppColors.success).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasDraft ? Icons.hourglass_empty_rounded : Icons.check_circle_outline_rounded,
                      color: hasDraft ? AppColors.warning : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasDraft ? 'Status: Belum Dibayar (Draft Active)' : 'Status: Kosong / Lunas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: hasDraft ? const Color(0xFF78350F) : const Color(0xFF14532D),
                            ),
                          ),
                          if (activeOrder != null) ...[
                            Text('No. Order: ${activeOrder.nomorOrder}', style: const TextStyle(fontSize: 12)),
                            Text(
                              'Total Tagihan: ${CurrencyFormatter.format(activeOrder.grandTotal)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Items List Grouped by Batch
              if (groupedItems.isNotEmpty) ...[
                Text('Rincian Pesanan per Batch:', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: groupedItems.entries.map((entry) {
                      final batchTitle = entry.key;
                      final batchItemList = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.soup_kitchen_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    batchTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${batchItemList.length} Menu',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            ...batchItemList.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.qty}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.produkNama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        if (item.catatan != null && item.catatan!.isNotEmpty)
                                          Text('Note: ${item.catatan}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else
                const Expanded(
                  child: Center(
                    child: Text('Belum ada rincian pesanan'),
                  ),
                ),
              const SizedBox(height: 12),
              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            ref.read(orderNotifierProvider.notifier).selectTable(table);
                            final products = ref.read(productNotifierProvider).allProducts;
                            final draftItems = await ref.read(orderRepositoryProvider).getOrderItems(activeOrder.id);
                            ref.read(cartNotifierProvider.notifier).loadDraftItems(draftItems, products);
                          },
                          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                          label: Text(hasDraft ? 'Tambah Menu' : 'Pesan Baru'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (hasDraft) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              ref.read(orderNotifierProvider.notifier).selectTable(table);
                              final products = ref.read(productNotifierProvider).allProducts;
                              final draftItems = await ref.read(orderRepositoryProvider).getOrderItems(activeOrder.id);
                              ref.read(cartNotifierProvider.notifier).loadDraftItems(draftItems, products);

                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PaymentScreen()),
                              );
                            },
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Bayar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasDraft) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _handleMoveTableInPos(table, activeOrder);
                            },
                            icon: const Icon(Icons.move_up_rounded, size: 18),
                            label: const Text('Pindah'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _handleCancelOrder(context);
                            },
                            icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: AppColors.error),
                            label: const Text('Kosongkan Meja', style: TextStyle(color: AppColors.error, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleMoveTableInPos(TableModel sourceTable, dynamic activeOrder) {
    final tableState = ref.read(tableNotifierProvider);
    final emptyTables = tableState.allTables.where((t) => t.isEmpty).toList();

    if (emptyTables.isEmpty) {
      AppSnackbar.showWarning(context, 'Tidak ada meja kosong yang tersedia untuk dipindahkan.');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pindahkan ${sourceTable.nama} ke:', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: emptyTables.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final targetTable = emptyTables[index];
                      return ListTile(
                        leading: const Icon(Icons.table_restaurant_rounded, color: AppColors.success),
                        title: Text(targetTable.nama),
                        subtitle: Text('Nomor: ${targetTable.nomor} (Kosong)'),
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await ref.read(orderRepositoryProvider).transferOrderTable(
                                activeOrder.id,
                                sourceTable.id,
                                targetTable.id,
                                targetTable.nama,
                                targetTable.nomor,
                              );
                          ref.read(tableNotifierProvider.notifier).loadTables();
                          ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
                          if (mounted) {
                            AppSnackbar.showSuccess(context, 'Berhasil memindahkan pesanan dari ${sourceTable.nama} ke ${targetTable.nama}');
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTakeAwayOptionsDialog(OrderNotifier orderNotifier) {
    showDialog(
      context: context,
      builder: (context) {
        return _TakeAwayOptionsDialog(
          onConfirm: (subType, platform) {
            orderNotifier.setOrderType('take_away', subType: subType, platform: platform);
          },
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
                    _showTakeAwayOptionsDialog(orderNotifier);
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
        if (isTakeAway) ...[
          if (orderState.takeAwaySubType != null)
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  'Tipe: ${orderState.takeAwaySubType == 'online' ? 'Online Food' : 'Reguler'}',
                  style: AppTypography.bodySmall.copyWith(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                ),
                if (orderState.onlinePlatform != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${orderState.onlinePlatform})',
                    style: AppTypography.bodySmall.copyWith(color: Colors.orange.shade800),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.orange),
                  onPressed: () => _showTakeAwayOptionsDialog(orderNotifier),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
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
                  onPressed: () => _showChangeTableDialog(),
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
                      AppButton(
                        text: 'Batal',
                        type: AppButtonType.destructive,
                        onPressed: () => _handleCancelOrder(context),
                        icon: Icons.cancel_outlined,
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

class _TakeAwayOptionsDialog extends ConsumerStatefulWidget {
  final void Function(String subType, String? platform) onConfirm;

  const _TakeAwayOptionsDialog({required this.onConfirm});

  @override
  ConsumerState<_TakeAwayOptionsDialog> createState() => _TakeAwayOptionsDialogState();
}

class _TakeAwayOptionsDialogState extends ConsumerState<_TakeAwayOptionsDialog> {
  String _subType = 'reguler'; // reguler or online
  String? _selectedPlatform;

  @override
  Widget build(BuildContext context) {
    final platformState = ref.watch(onlinePlatformNotifierProvider);
    final platforms = platformState.platforms;

    return AlertDialog(
      title: const Text('Opsi Take Away'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<String>(
            title: const Text('Reguler'),
            value: 'reguler',
            groupValue: _subType,
            onChanged: (value) {
              setState(() {
                _subType = value!;
                _selectedPlatform = null;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Online Food'),
            value: 'online',
            groupValue: _subType,
            onChanged: (value) {
              setState(() {
                _subType = value!;
                if (platforms.isNotEmpty) {
                  _selectedPlatform = platforms.first.nama;
                }
              });
            },
          ),
          if (_subType == 'online') ...[
            const SizedBox(height: 12),
            if (platformState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (platforms.isEmpty)
              const Text('Belum ada platform online terdaftar.', style: TextStyle(color: AppColors.error))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedPlatform,
                decoration: const InputDecoration(
                  labelText: 'Pilih Platform',
                  border: OutlineInputBorder(),
                ),
                items: platforms.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.nama,
                    child: Text(p.nama),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlatform = value;
                  });
                },
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_subType == 'online' && _selectedPlatform == null) {
              AppSnackbar.showWarning(context, 'Pilih platform terlebih dahulu.');
              return;
            }
            widget.onConfirm(_subType, _selectedPlatform);
            Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
