import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../product/application/product_notifier.dart';

import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../application/online_platform_notifier.dart';
import '../../domain/models/order.dart';
import 'table_selector_screen.dart';
import 'cashier_screen.dart';

class OrderHubScreen extends ConsumerStatefulWidget {
  const OrderHubScreen({super.key});

  @override
  ConsumerState<OrderHubScreen> createState() => _OrderHubScreenState();
}

class _OrderHubScreenState extends ConsumerState<OrderHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
      ref.read(productNotifierProvider.notifier).loadProducts();
    });
  }

  void _handleDineInSelected() {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    orderNotifier.setOrderType('dine_in');
    cartNotifier.clear();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TableSelectorScreen()),
    ).then((_) {
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  void _handleTakeAwaySelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Tipe Take Away', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pilih kategori layanan pesanan bungkus/bawa pulang:'),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.divider),
              ),
              leading: const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 28),
              title: const Text('Take Away Reguler', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pesanan langsung oleh pelanggan di kasir toko'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCashierForTakeAway('reguler');
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.orange),
              ),
              tileColor: Colors.orange.shade50,
              leading: Icon(Icons.sports_esports_rounded, color: Colors.orange.shade800, size: 28),
              title: Text('Online Food', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
              subtitle: const Text('Pesanan via aplikasi GoFood/GrabFood/ShopeeFood'),
              onTap: () {
                Navigator.pop(context);
                _showOnlinePlatformSelectionDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOnlinePlatformSelectionDialog() {
    ref.read(onlinePlatformNotifierProvider.notifier).loadPlatforms();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Consumer(
          builder: (context, ref, child) {
            final platformState = ref.watch(onlinePlatformNotifierProvider);
            final activePlatforms = platformState.platforms.where((p) => p.isActive).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.delivery_dining_rounded, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pilih Platform',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Pilih aplikasi penyedia layanan online food:'),
                    const SizedBox(height: 12),
                    if (platformState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (activePlatforms.isEmpty) ...[
                      const Text(
                        'Belum ada platform online tersimpan.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ] else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: activePlatforms.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index == activePlatforms.length) {
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: AppColors.divider),
                                ),
                                leading: const Icon(Icons.other_houses_rounded, color: AppColors.textSecondary),
                                title: const Text('Lainnya / Umum', style: TextStyle(fontWeight: FontWeight.w600)),
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _navigateToCashierForTakeAway('online_food', platform: 'Online Food');
                                },
                              );
                            }
                            final platform = activePlatforms[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.orange.shade300),
                              ),
                              tileColor: Colors.orange.shade50,
                              leading: Icon(Icons.delivery_dining_rounded, color: Colors.orange.shade800),
                              title: Text(platform.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.orange),
                              onTap: () {
                                Navigator.pop(dialogCtx);
                                _navigateToCashierForTakeAway('online_food', platform: platform.nama);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToCashierForTakeAway(String subType, {String? platform}) {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);

    orderNotifier.resetOrder();
    orderNotifier.setOrderType('take_away', subType: subType, platform: platform);
    cartNotifier.clear();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashierScreen()),
    ).then((_) {
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  Future<void> _handleDraftOrderSelected(OrderModel order) async {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productState = ref.read(productNotifierProvider);

    if (order.tableId != null && order.tableId!.isNotEmpty && order.tableId != 'TABLE_TAKE_AWAY') {
      await orderNotifier.loadActiveOrderForTable(order.tableId!);
    } else {
      await orderNotifier.loadOrderById(order.id);
    }
    final orderState = ref.read(orderNotifierProvider);

    if (orderState.activeOrder != null) {
      cartNotifier.loadDraftItems(orderState.activeOrderItems, productState.allProducts);
    } else {
      cartNotifier.clear();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashierScreen()),
    ).then((_) {
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider);
    final draftOrders = orderState.allDraftOrders;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Transaksi POS - Pesanan Barus & Aktif'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Pesanan',
            onPressed: () {
              ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Buttons: Dine In & Take Away
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _handleDineInSelected,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.restaurant_rounded, size: 38, color: AppColors.primary),
                            const SizedBox(height: 6),
                            Text(
                              'Dine-In',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Makan di tempat (Pilih Meja)',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: InkWell(
                      onTap: _handleTakeAwaySelected,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.secondary, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.shopping_bag_rounded, size: 38, color: AppColors.secondary),
                            const SizedBox(height: 6),
                            Text(
                              'Takeaway',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bungkus / Online Food',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),

              // Bottom Section Header: Daftar Pesanan Aktif
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Daftar Pesanan Aktif (${draftOrders.length})',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (draftOrders.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Draft / Open Bill',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.m),

              // Draft Orders List
              Expanded(
                child: orderState.isLoading && draftOrders.isEmpty
                    ? const AppLoading(message: 'Memuat pesanan aktif...')
                    : draftOrders.isEmpty
                        ? const AppEmptyState(
                            title: 'Belum Ada Pesanan Aktif',
                            description: 'Pilih "Dine In" atau "Take Away" di atas untuk membuat pesanan baru.',
                            icon: Icons.receipt_long_outlined,
                          )
                        : ListView.separated(
                            itemCount: draftOrders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
                            itemBuilder: (context, index) {
                              final order = draftOrders[index];
                              final isDineIn = order.orderType == 'dine_in';
                              final formattedTime = DateFormat('HH:mm').format(order.createdAt);

                              return AppCard(
                                onTap: () => _handleDraftOrderSelected(order),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDineIn
                                            ? AppColors.primary.withValues(alpha: 0.1)
                                            : AppColors.secondary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isDineIn ? Icons.table_restaurant_rounded : Icons.shopping_bag_rounded,
                                        color: isDineIn ? AppColors.primary : AppColors.secondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 6,
                                            runSpacing: 2,
                                            children: [
                                              Text(
                                                order.nomorOrder,
                                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDineIn ? Colors.blue.shade50 : Colors.orange.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isDineIn
                                                      ? 'Meja: ${order.tableNama ?? order.tableNomor ?? '-'}'
                                                      : 'Take Away (${order.takeAwaySubType == 'online_food' ? 'Online' : 'Reguler'})',
                                                  style: TextStyle(
                                                    color: isDineIn ? Colors.blue.shade800 : Colors.orange.shade800,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Waktu: $formattedTime • Pelanggan: ${order.customerName ?? 'Umum'}',
                                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            CurrencyFormatter.format(order.grandTotal),
                                            style: AppTypography.titleMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Row(
                                          children: [
                                            Text(
                                              'Buka Kasir',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.primary),
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
      ),
    );
  }
}
