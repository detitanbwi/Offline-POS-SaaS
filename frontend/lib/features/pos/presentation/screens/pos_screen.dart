// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import 'payment_screen.dart';
import '../../../table/application/table_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _customerNameController = TextEditingController();
  late TabController _posTabController;
  String? _selectedCategoryId;
  Timer? _debounceTimer;
  String _searchQuery = '';
  bool _isOrderAscending = false;
  String _orderFilter = 'all'; // 'all', 'dine_in', 'take_away'

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'processing':
        return Colors.blue;
      case 'served':
        return Colors.orange;
      case 'completed':
        return AppColors.success;
      case 'draft':
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'billed':
        return Colors.purple;
      case 'partially_paid':
        return Colors.yellow.shade800;
      case 'paid':
        return AppColors.success;
      case 'unpaid':
      default:
        return AppColors.error;
    }
  }

  @override
  void initState() {
    super.initState();
    _posTabController = TabController(length: 2, vsync: this);
    // Refresh daftar Open Bill setiap kali user tap ke tab "Pesanan"
    _posTabController.addListener(() {
      if (_posTabController.index == 1 && !_posTabController.indexIsChanging) {
        ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
      }
    });
    // Pre-load products, categories, tables, and active orders map
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Tunggu animasi transisi layar dan penutupan keyboard selesai
      // agar UI tidak freeze saat memuat banyak data secara bersamaan.
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

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
    _posTabController.dispose();
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
        ref.read(cartNotifierProvider.notifier).updateCatatan(item.product.id, noteController.text, batchId: item.batchId);
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
          title: Text('Transaksi POS', style: TextStyle(fontSize: isMobileLandscape ? 14 : 16, fontWeight: FontWeight.bold)),
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
                      child: _posTabController.index == 0
                          ? _buildCatalogGrid(activeProducts, productState.isLoading, cartNotifier)
                          : _buildOpenOrdersList(),
                    ),
                    if (_posTabController.index == 0) const SizedBox(height: 72),
                  ],
                ),
                if (_posTabController.index == 0 && cartState.items.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildMobileCartBar(context, cartState),
                  ),
              ],
            ),
            // Mobile Landscape Layout
            mobileLandscape: Stack(
              children: [
                Column(
                  children: [
                    _buildCatalogHeader(activeCategories),
                    Expanded(
                      child: _posTabController.index == 0
                          ? _buildCatalogGrid(activeProducts, productState.isLoading, cartNotifier)
                          : _buildOpenOrdersList(),
                    ),
                    if (_posTabController.index == 0) const SizedBox(height: 64),
                  ],
                ),
                if (_posTabController.index == 0 && cartState.items.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildMobileCartBar(context, cartState),
                  ),
              ],
            ),
            // Tablet Split Layout
            tablet: Row(
              children: [
                // Left side: Catalog / Orders List
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildCatalogHeader(activeCategories),
                      Expanded(
                        child: _posTabController.index == 0
                            ? _buildCatalogGrid(activeProducts, productState.isLoading, cartNotifier)
                            : _buildOpenOrdersList(),
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
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Keluar Transaksi POS',
        message: 'Apakah Anda yakin ingin keluar?',
        confirmText: 'Keluar',
        cancelText: 'Batal',
        isDestructive: true,
        onConfirm: () {
          Navigator.pop(dialogContext, true);
        },
        onCancel: () {
          Navigator.pop(dialogContext, false);
        },
      ),
    );
    return result ?? false;
  }

  Future<bool> _ensureTableSelected() async {
    final orderState = ref.read(orderNotifierProvider);
    if (orderState.isTakeAway || orderState.selectedTable != null || orderState.activeOrder?.tableId != null) {
      return true; // Take Away or table already selected/assigned
    }

    final tableState = ref.read(tableNotifierProvider);
    if (tableState.allTables.isEmpty) {
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
                final allTables = tableState.allTables;
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

                            return ListTile(
                              dense: isMobileLandscape,
                              leading: Icon(
                                Icons.table_restaurant_rounded,
                                color: isOccupied ? AppColors.secondary : AppColors.success,
                              ),
                              title: Text(table.nama, style: TextStyle(fontSize: isMobileLandscape ? 13 : 14)),
                              subtitle: Text(
                                isOccupied
                                    ? 'Terisi / Billed - Kelola via Manajemen Meja'
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
                                if (isOccupied) {
                                  AppSnackbar.showWarning(
                                    context,
                                    'Meja ini berstatus Terisi/Billed. Gunakan Manajemen Meja untuk mengelola meja.',
                                  );
                                  return;
                                }
                                 ref.read(orderNotifierProvider.notifier).selectTable(table);
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

  Widget _buildCatalogHeader(List<dynamic> activeCategories) {
    final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);
    final orderState = ref.watch(orderNotifierProvider);
    final openBillCount = orderState.allDraftOrders.length;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobileLandscape ? AppSpacing.s : AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Tab Bar: Kasir vs Pesanan (Open Bill)
          Container(
            height: isMobileLandscape ? 36 : 42,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _posTabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primary,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              onTap: (_) => setState(() {}),
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.point_of_sale_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Kasir'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 18),
                      const SizedBox(width: 6),
                      const Text('Pesanan'),
                      if (openBillCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _posTabController.index == 1 ? Colors.white : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$openBillCount',
                            style: TextStyle(
                              color: _posTabController.index == 1 ? AppColors.primary : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_posTabController.index == 0) ...[
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
        ],
      ),
    );
  }

  Widget _buildOpenOrdersList() {
    final orderState = ref.watch(orderNotifierProvider);
    final allDrafts = orderState.allDraftOrders;

    if (allDrafts.isEmpty) {
      return const AppEmptyState(
        title: 'Belum Ada Pesanan Aktif (Open Bill)',
        description: 'Pesanan yang belum dibayar (Dine-In maupun Take Away) akan muncul di sini.',
        icon: Icons.receipt_long_rounded,
      );
    }

    final filteredDrafts = allDrafts.where((order) {
      if (_orderFilter == 'dine_in') return order.orderType == 'dine_in';
      if (_orderFilter == 'take_away') return order.orderType == 'take_away';
      return true;
    }).toList();

    final sortedDrafts = List<OrderModel>.from(filteredDrafts);
    sortedDrafts.sort((a, b) => _isOrderAscending
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt));

    final dineInCount = allDrafts.where((o) => o.orderType == 'dine_in').length;
    final takeawayCount = allDrafts.where((o) => o.orderType == 'take_away').length;

    return Column(
      children: [
        // Sort & Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${allDrafts.length} Pesanan Aktif',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isOrderAscending = !_isOrderAscending;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isOrderAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isOrderAscending ? 'Terlama (Asc)' : 'Terbaru (Desc)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filter Chips: Semua / Dine-In / Takeaway
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPosFilterChip('Semua', 'all', allDrafts.length, AppColors.primary, Icons.list_alt_rounded),
                    const SizedBox(width: 8),
                    _buildPosFilterChip('Dine-In', 'dine_in', dineInCount, Colors.blue.shade700, Icons.restaurant_rounded),
                    const SizedBox(width: 8),
                    _buildPosFilterChip('Takeaway', 'take_away', takeawayCount, Colors.orange.shade800, Icons.shopping_bag_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sortedDrafts.isEmpty
              ? AppEmptyState(
                  title: _orderFilter == 'dine_in' ? 'Tidak Ada Pesanan Dine-In' : 'Tidak Ada Pesanan Takeaway',
                  description: 'Tidak ada pesanan aktif untuk kategori ini.',
                  icon: Icons.receipt_long_rounded,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 4),
                  itemCount: sortedDrafts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = sortedDrafts[index];
                    final isTakeAway = order.isTakeAway;
                    final tableName = order.tableNama ?? (isTakeAway ? 'Take Away' : 'Meja -');
                    final timeFormatted = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);

              return AppCard(
                padding: const EdgeInsets.all(16),
                borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isTakeAway ? Colors.orange.shade50 : AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isTakeAway ? Icons.shopping_bag_rounded : Icons.table_restaurant_rounded,
                            color: isTakeAway ? Colors.orange.shade800 : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tableName,
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (order.customerName != null && order.customerName!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        order.customerName!,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'No. Order: ${order.nomorOrder}',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeFormatted,
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // Order Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getOrderStatusColor(order.status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _getOrderStatusColor(order.status).withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      order.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _getOrderStatusColor(order.status),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Payment Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getPaymentStatusColor(order.paymentStatus).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _getPaymentStatusColor(order.paymentStatus).withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      order.paymentStatus.replaceAll('_', ' ').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _getPaymentStatusColor(order.paymentStatus),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(order.grandTotal),
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // 1. Load order & active items ke order state
                    await ref.read(orderNotifierProvider.notifier).loadOrderById(order.id);
                    if (!isTakeAway && order.tableId != null) {
                      final table = await ref.read(tableRepositoryProvider).getTableById(order.tableId!);
                      if (table != null) {
                        ref.read(orderNotifierProvider.notifier).setSelectedTableWithoutReset(table);
                      }
                    }

                    // 2. Load item ke cart
                    final items = await ref.read(orderRepositoryProvider).getOrderItems(order.id);
                    final products = ref.read(productNotifierProvider).allProducts;
                    final batches = ref.read(orderNotifierProvider).activePrintBatches;
                    ref.read(cartNotifierProvider.notifier).loadDraftItems(items, products, batches);

                    // 3. Pindah ke segmen Kasir
                    _posTabController.animateTo(0);

                    // 4. Buka Bottom Sheet Keranjang menggunakan root context PosScreen
                    _openCartBottomSheet(this.context);
                  },
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Bayar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
);
  }

  void _openCartBottomSheet(BuildContext parentContext) {
    debugPrint('[DEBUG_BAYAR] Inside _openCartBottomSheet function');
    bool isSaving = false;
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (sheetContext2, scrollController) => StatefulBuilder(
          builder: (context, setStateSheet) => Container(
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
                      _buildOrderTypeAndCustomerSection(parentContext, orderState, orderNotifier),
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
                                onNoteTap: () => _showNoteDialog(parentContext, item),
                              ),
                              const Divider(),
                            ],
                          ),
                        ),
                      _buildBillSummary(cState),
                      const SizedBox(height: 12),
                      // Top Row: Kirim ke Dapur & Bayar Now
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              type: AppButtonType.outlined,
                              isLoading: isSaving,
                              onPressed: cState.items.isEmpty || isSaving
                                  ? null
                                  : () async {
                                      setStateSheet(() => isSaving = true);
                                      await Future.delayed(const Duration(milliseconds: 100)); // Allow UI update

                                      if (await _ensureTableSelected()) {
                                        final authUser = ref.read(authSessionProvider);
                                        final savedItems = await orderNotifier.saveCurrentOrderDraft(
                                          cState.items,
                                          cState.subtotal,
                                          cState.taxRate,
                                          cState.taxAmount,
                                          cState.grandTotal,
                                          cashierId: authUser?.id,
                                          cashierNama: authUser?.nama,
                                          printToKitchen: true,
                                        );

                                        if (!mounted) return;
                                        Navigator.of(sheetContext).pop(); // Pop sheet AFTER done
                                        
                                        if (savedItems != null) {
                                          cNotifier.clear();
                                          orderNotifier.resetForNewTransaction();
                                          AppSnackbar.showSuccess(parentContext, 'Pesanan terkirim ke Dapur & disimpan (Bayar Nanti).');
                                        } else {
                                          final err = ref.read(orderNotifierProvider).errorMessage;
                                          AppSnackbar.showError(parentContext, err ?? 'Gagal menyimpan pesanan.');
                                        }
                                      } else {
                                        if (mounted) setStateSheet(() => isSaving = false);
                                      }
                                    },
                              icon: Icons.soup_kitchen_rounded,
                              text: 'Kirim ke Dapur',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: (orderState.activeOrder?.isPaid ?? false)
                                ? AppButton(
                                    type: AppButtonType.primary,
                                    isLoading: isSaving,
                                    onPressed: isSaving ? null : () async {
                                      setStateSheet(() => isSaving = true);
                                      await Future.delayed(const Duration(milliseconds: 100));

                                      final orderId = orderState.activeOrder!.id;
                                      final tableId = orderState.activeOrder!.tableId;
                                      await ref.read(orderRepositoryProvider).completeOrder(orderId, tableId: tableId);
                                      cNotifier.clear();
                                      orderNotifier.resetForNewTransaction();
                                      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
                                      ref.read(tableNotifierProvider.notifier).loadTables();
                                      
                                      if (!mounted) return;
                                      Navigator.of(sheetContext).pop();
                                      AppSnackbar.showSuccess(context, 'Meja dibersihkan dan pesanan diselesaikan.');
                                    },
                                    icon: Icons.cleaning_services_rounded,
                                    text: 'Bersihkan Meja',
                                  )
                                : AppButton(
                                    type: AppButtonType.primary,
                                    isLoading: isSaving,
                                    onPressed: cState.items.isEmpty || isSaving
                                        ? null
                                        : () async {
                                            setStateSheet(() => isSaving = true);
                                            
                                            if (await _ensureTableSelected()) {
                                              if (!mounted) return;
                                              Navigator.of(sheetContext).pop();
                                              await Navigator.of(context, rootNavigator: true).push(
                                                MaterialPageRoute(builder: (_) => const PaymentScreen()),
                                              );
                                              if (!mounted) return;
                                              ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
                                            } else {
                                              if (mounted) setStateSheet(() => isSaving = false);
                                            }
                                          },
                                    icon: Icons.payments_rounded,
                                    text: 'Bayar Now',
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              final activeOrd = orderState.activeOrder;
                              Navigator.of(sheetContext).pop(); // Pop sheet dulu agar dialog tidak terhalang
                              if (activeOrd != null) {
                                _showRePrintKitchenDialog(parentContext, activeOrd);
                              } else {
                                AppSnackbar.showWarning(parentContext, 'Silakan simpan pesanan terlebih dahulu sebelum cetak ulang dapur.');
                              }
                            },
                            icon: const Icon(Icons.print_rounded, size: 16, color: AppColors.primary),
                            label: const Text('Cetak Ulang Dapur', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              cNotifier.clear();
                              orderNotifier.resetForNewTransaction();
                              Navigator.of(sheetContext).pop();
                              AppSnackbar.showSuccess(parentContext, 'Siap untuk transaksi baru.');
                            },
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                            label: const Text('Transaksi Baru', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRePrintKitchenDialog(BuildContext ctx, OrderModel order) async {
    final repository = ref.read(orderRepositoryProvider);
    final countFromDb = await repository.getBatchCount(order.id);
    if (!ctx.mounted) return;

    final effectiveBatchCount = countFromDb == 0 ? 1 : countFromDb;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.soup_kitchen_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Cetak Ulang Struk Dapur', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih batch pesanan yang ingin dicetak ulang ke printer dapur:',
              style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...List.generate(effectiveBatchCount, (index) {
              final bNum = index + 1;
              final bLabel = bNum == 1 ? 'Batch #1 (Pesanan Awal)' : 'Batch #$bNum (Pesanan Tambahan)';
              return ListTile(
                dense: true,
                leading: const Icon(Icons.print_rounded, size: 20, color: AppColors.primary),
                title: Text(bLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  await _reprintKitchenBatch(ctx, order, bNum);
                },
              );
            }),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.success),
              title: const Text('Cetak Rekap Dapur (Semua Menu)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
              onTap: () async {
                Navigator.pop(dialogCtx);
                await _reprintKitchenBatch(ctx, order, 0);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _reprintKitchenBatch(BuildContext ctx, OrderModel order, int batchNumber) async {
    try {
      final items = await ref.read(orderRepositoryProvider).getOrderItems(order.id);
      List<OrderItemModel> itemsToPrint = [];

      if (batchNumber == 0) {
        itemsToPrint = items.where((i) => !i.isCancelled).toList();
      } else {
        final batches = await ref.read(orderRepositoryProvider).getPrintBatches(order.id);
        if (batches.length >= batchNumber) {
          final targetBatchId = batches[batchNumber - 1]['id'] as String;
          itemsToPrint = items.where((i) => i.printBatchId == targetBatchId && !i.isCancelled).toList();
        }
      }

      if (itemsToPrint.isEmpty) {
        AppSnackbar.showWarning(ctx, 'Tidak ada item menu pada batch ini.');
        return;
      }

      final waveInfo = batchNumber == 0
          ? '[REKAP DAPUR]'
          : (batchNumber == 1 ? '#1 (Pesanan Awal - CETAK ULANG)' : '#$batchNumber (Tambahan - CETAK ULANG)');

      await ref.read(printerNotifierProvider.notifier).loadPrinters();
      final printerState = ref.read(printerNotifierProvider);
      final kitchenPrinters = printerState.configuredPrinters.where((p) => p.isKitchen).toList();
      final targetPrinter = kitchenPrinters.isNotEmpty
          ? kitchenPrinters.first
          : (printerState.configuredPrinters.isNotEmpty ? printerState.configuredPrinters.first : null);

      final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
        order: order,
        itemsToPrint: itemsToPrint,
        waveInfo: waveInfo,
        paperSize: targetPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: targetPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: targetPrinter?.autoCut ?? false,
      );

      if (targetPrinter != null) {
        await ref.read(printerNotifierProvider.notifier).printBytes(targetPrinter, receiptBytes);
        AppSnackbar.showSuccess(ctx, 'Struk Dapur $waveInfo berhasil dicetak.');
      } else {
        AppSnackbar.showSuccess(ctx, 'Simulasi Struk Dapur $waveInfo (Printer tidak terhubung).');
      }
    } catch (e) {
      AppSnackbar.showError(ctx, 'Gagal mencetak ulang dapur: $e');
    }
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
        final effectiveStock = product.getEffectiveStock(allProducts: products);
        final isOutOfStock = effectiveStock != -1 && effectiveStock <= 0;

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
                                cacheWidth: 300,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 28),
                                ),
                              )
                            : Image.file(
                                    File(product.image!),
                                    fit: BoxFit.contain,
                                    cacheWidth: 300,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 28),
                                    ),
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
                              isOutOfStock
                                  ? 'Habis'
                                  : (product.isPackage
                                      ? (effectiveStock == -1 ? 'Paket' : 'Pkt: $effectiveStock')
                                      : (effectiveStock == -1 ? 'Stok: ∞' : 'Stok: $effectiveStock')),
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
        AppTextField(
          controller: _customerNameController,
          onChanged: (val) => orderNotifier.setCustomerName(val),
          debounceDuration: const Duration(milliseconds: 500),
          labelText: 'Atas Nama / Nama Customer (Opsional)',
          prefixIcon: Icons.person_outline_rounded,
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
                    AppButton(
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
                      width: double.infinity,
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
            AppButton(
              text: 'Lanjutkan',
              onPressed: () => _openCartBottomSheet(rootContext),
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ),
      ),
    );
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

  Widget _buildPosFilterChip(String label, String value, int count, Color activeColor, IconData icon) {
    final isSelected = _orderFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _orderFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : activeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : activeColor.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.sp,
              color: isSelected ? Colors.white : activeColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.sp,
                color: isSelected ? Colors.white : activeColor,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : activeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10.sp,
                  color: isSelected ? Colors.white : activeColor,
                ),
              ),
            ),
          ],
        ),
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
                    if (item.batchName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isBilled ? Colors.grey.shade300 : AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.isBilled ? '${item.batchName} (Billed)' : item.batchName!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.isBilled ? Colors.grey.shade700 : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
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
                    if (item.product.isPackage && item.product.packageItems.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...item.product.packageItems.map((comp) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${comp.qty * item.qty}x ${comp.productNama ?? "Item"}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
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
                    onPressed: () => cartNotifier.updateQuantity(item.product.id, item.qty - 1, batchId: item.batchId),
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
                    onPressed: () => cartNotifier.updateQuantity(item.product.id, item.qty + 1, batchId: item.batchId),
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
      content: SingleChildScrollView(
        child: Column(
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
