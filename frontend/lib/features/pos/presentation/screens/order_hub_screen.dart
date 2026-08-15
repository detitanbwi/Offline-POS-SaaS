import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../../core/di/providers.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../product/application/product_notifier.dart';
import '../../../table/application/table_notifier.dart';
import '../../../table/domain/models/table.dart';

import '../../../security/presentation/providers/security_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../application/online_platform_notifier.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../core/utils/pdf_receipt_generator.dart';
import '../../../../core/widgets/app_receipt_preview_modal.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../printer/application/printer_notifier.dart';

import 'table_selector_screen.dart';
import 'cashier_screen.dart';
import 'payment_screen.dart';

class OrderHubScreen extends ConsumerStatefulWidget {
  const OrderHubScreen({super.key});

  @override
  ConsumerState<OrderHubScreen> createState() => _OrderHubScreenState();
}

class _OrderHubScreenState extends ConsumerState<OrderHubScreen> {
  String _orderFilter = 'all'; // 'all', 'dine_in', 'take_away'
  bool _isNavigatingToDineIn = false;
  String? _loadingOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
      ref.read(productNotifierProvider.notifier).loadProducts();
    });
  }

  void _handleDineInSelected() async {
    setState(() => _isNavigatingToDineIn = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    orderNotifier.setOrderType('dine_in');
    cartNotifier.clear();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TableSelectorScreen()),
    );

    if (mounted) {
      setState(() => _isNavigatingToDineIn = false);
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    }
  }

  void _handleTakeAwaySelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.shopping_bag_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Tipe Take Away',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pilih kategori layanan pesanan bungkus/bawa pulang:'),
            SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.divider),
              ),
              leading: Icon(
                Icons.person_pin_circle_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              title: Text(
                'Take Away Reguler',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Pesanan langsung oleh pelanggan di kasir toko'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCashierForTakeAway('reguler');
              },
            ),
            SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.orange),
              ),
              tileColor: Colors.orange.shade50,
              leading: Icon(
                Icons.sports_esports_rounded,
                color: Colors.orange.shade800,
                size: 28,
              ),
              title: Text(
                'Online Food',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              subtitle: Text('Pesanan via aplikasi GoFood/GrabFood/ShopeeFood'),
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
            final activePlatforms = platformState.platforms
                .where((p) => p.isActive)
                .toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.orange.shade800,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pilih Platform',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                    Text('Pilih aplikasi penyedia layanan online food:'),
                    SizedBox(height: 12),
                    if (platformState.isLoading)
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (activePlatforms.isEmpty) ...[
                      Text(
                        'Belum ada platform online tersimpan.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ] else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: activePlatforms.length + 1,
                          separatorBuilder: (_, _) => SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index == activePlatforms.length) {
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: AppColors.divider,
                                  ),
                                ),
                                leading: Icon(
                                  Icons.other_houses_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                title: Text(
                                  'Lainnya / Umum',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  _navigateToCashierForTakeAway(
                                    'online_food',
                                    platform: 'Online Food',
                                  );
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
                              leading: Icon(
                                Icons.delivery_dining_rounded,
                                color: Colors.orange.shade800,
                              ),
                              title: Text(
                                platform.nama,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.orange,
                              ),
                              onTap: () {
                                Navigator.pop(dialogCtx);
                                _navigateToCashierForTakeAway(
                                  'online_food',
                                  platform: platform.nama,
                                );
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
                  child: Text('Batal'),
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
    orderNotifier.setOrderType(
      'take_away',
      subType: subType,
      platform: platform,
    );
    cartNotifier.clear();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashierScreen()),
    ).then((_) {
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  Future<void> _navigateToPos(OrderModel order) async {
    final freshOrder = await ref
        .read(orderRepositoryProvider)
        .getOrderById(order.id);
    if (freshOrder != null && freshOrder.isCompleted) {
      if (mounted) {
        AppSnackbar.showWarning(
          context,
          'Pesanan ini sudah selesai / dibayar.',
        );
        ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
      }
      return;
    }

    if (freshOrder != null && freshOrder.isBillPrinted) {
      if (mounted) {
        AppSnackbar.showWarning(
          context,
          'Pesanan sudah di-bill. Tidak dapat menambah menu lagi.',
        );
      }
      return;
    }

    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productState = ref.read(productNotifierProvider);

    if (order.tableId != null &&
        order.tableId!.isNotEmpty &&
        order.tableId != 'TABLE_TAKE_AWAY') {
      await orderNotifier.loadActiveOrderForTable(order.tableId!);
    } else {
      await orderNotifier.loadOrderById(order.id);
    }
    final orderState = ref.read(orderNotifierProvider);

    if (orderState.activeOrder != null) {
      cartNotifier.loadDraftItems(
        orderState.activeOrderItems,
        productState.allProducts,
        orderState.activePrintBatches,
      );
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

  Future<void> _navigateToPayment(OrderModel order) async {
    final freshOrder = await ref
        .read(orderRepositoryProvider)
        .getOrderById(order.id);
    if (freshOrder != null && freshOrder.isCompleted) {
      if (mounted) {
        AppSnackbar.showWarning(
          context,
          'Pesanan ini sudah selesai / dibayar.',
        );
        ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
      }
      return;
    }

    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productState = ref.read(productNotifierProvider);

    if (order.tableId != null &&
        order.tableId!.isNotEmpty &&
        order.tableId != 'TABLE_TAKE_AWAY') {
      await orderNotifier.loadActiveOrderForTable(order.tableId!);
    } else {
      await orderNotifier.loadOrderById(order.id);
    }
    final orderState = ref.read(orderNotifierProvider);

    if (orderState.activeOrder != null) {
      cartNotifier.loadDraftItems(
        orderState.activeOrderItems,
        productState.allProducts,
        orderState.activePrintBatches,
      );
    } else {
      cartNotifier.clear();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentScreen()),
    ).then((_) {
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  Future<void> _showOrderActionBottomSheet(OrderModel order) async {
    final repo = ref.read(orderRepositoryProvider);
    final isDineIn = order.orderType == 'dine_in';

    TableModel? table;
    if (isDineIn && order.tableId != null) {
      final tableState = ref.read(tableNotifierProvider);
      try {
        table = tableState.allTables.firstWhere((t) => t.id == order.tableId);
      } catch (e) {
        // Table not found in state
      }
    }

    final initialIsBillPrinted =
        order.isBillPrinted || (table?.isBillPrinted ?? false);
    final title = isDineIn
        ? 'Rincian Meja ${order.tableNomor ?? '-'}'
        : 'Rincian Take Away (${order.takeAwaySubType == 'online_food' ? 'Online${order.onlinePlatform != null ? " - ${order.onlinePlatform}" : ""}' : 'Reguler'})';

    List<OrderItemModel> items = await repo.getOrderItems(order.id);
    List<Map<String, dynamic>> batches = await repo.getPrintBatches(order.id);

    final Map<String, int> batchIndexMap = {};
    for (int i = 0; i < batches.length; i++) {
      final bId = batches[i]['id'] as String;
      batchIndexMap[bId] = i + 1;
    }

    final Map<String, List<OrderItemModel>> groupedItems = {};

    for (var item in items) {
      String batchTitle = 'Batch #1';
      if (item.printBatchId != null &&
          batchIndexMap.containsKey(item.printBatchId)) {
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
        bool isProcessing = false;
        Set<String> expandedBatches = {};
        bool isBillPrinted = initialIsBillPrinted;
        
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final statusLabel = isBillPrinted
                ? 'Bill Dicetak'
                : (table != null
                      ? table.statusLabel
                      : (order.isDraft ? 'Open Bill' : 'Selesai'));
            final statusColor = isBillPrinted ? AppColors.warning : AppColors.success;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: AppLoading(message: 'Memproses...'),
                    )
                  : SingleChildScrollView(
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
                                    title,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (order.customerName != null &&
                                      order.customerName!.isNotEmpty)
                                    Text(
                                      'Atas Nama: ${order.customerName}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Status Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isBillPrinted
                                      ? Icons.receipt_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: statusColor,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Status: $statusLabel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.sp,
                                          color: isBillPrinted
                                              ? const Color(0xFF78350F)
                                              : const Color(0xFF14532D),
                                        ),
                                      ),
                                      Text(
                                        'No. Order: ${order.nomorOrder}',
                                        style: TextStyle(fontSize: 12.sp),
                                      ),
                                      Text(
                                        'Total Tagihan: ${CurrencyFormatter.format(order.grandTotal)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.sp,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          // Items List Grouped by Batch
                          if (groupedItems.isNotEmpty) ...[
                            Text(
                              'Rincian Pesanan per Batch:',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            ListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: groupedItems.entries.map((entry) {
                                final batchTitle = entry.key;
                                final batchItemList = entry.value;
                                final hasActiveItemsInBatch = batchItemList.any(
                                  (i) => !i.isCancelled,
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setStateSheet(() {
                                            if (expandedBatches.contains(
                                              batchTitle,
                                            )) {
                                              expandedBatches.remove(
                                                batchTitle,
                                              );
                                            } else {
                                              expandedBatches.add(batchTitle);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryContainer
                                                .withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.vertical(
                                              top: const Radius.circular(9),
                                              bottom: Radius.circular(
                                                expandedBatches.contains(
                                                      batchTitle,
                                                    )
                                                    ? 0
                                                    : 9,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.soup_kitchen_rounded,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                batchTitle,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.sp,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${batchItemList.length} Menu',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              if (hasActiveItemsInBatch &&
                                                  batchItemList
                                                          .first
                                                          .printBatchId !=
                                                      null)
                                                InkWell(
                                                  onTap: () {
                                                    Navigator.pop(sheetContext);
                                                    _showCancelDialog(
                                                      context,
                                                      order,
                                                      batchId: batchItemList
                                                          .first
                                                          .printBatchId,
                                                    );
                                                  },
                                                  child: Padding(
                                                    padding: EdgeInsets.all(6),
                                                    child: Icon(
                                                      Icons.cancel_outlined,
                                                      size: 20,
                                                      color: AppColors.error,
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(width: 4),
                                              Icon(
                                                expandedBatches.contains(
                                                      batchTitle,
                                                    )
                                                    ? Icons
                                                          .keyboard_arrow_up_rounded
                                                    : Icons
                                                          .keyboard_arrow_down_rounded,
                                                size: 20,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (expandedBatches.contains(batchTitle))
                                        ...batchItemList.map(
                                          (item) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${item.qty}x',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13.sp,
                                                    decoration: item.isCancelled
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                    color: item.isCancelled
                                                        ? Colors.grey
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              item.produkNama,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 13.sp,
                                                                decoration:
                                                                    item.isCancelled
                                                                    ? TextDecoration
                                                                          .lineThrough
                                                                    : null,
                                                                color:
                                                                    item.isCancelled
                                                                    ? Colors
                                                                          .grey
                                                                    : Colors
                                                                          .black87,
                                                              ),
                                                            ),
                                                          ),
                                                          if (item.isCancelled)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .shade100,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                'DIBATALKAN',
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      9.sp,
                                                                  color: Colors
                                                                      .red
                                                                      .shade800,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      if (item.catatan !=
                                                              null &&
                                                          item
                                                              .catatan!
                                                              .isNotEmpty)
                                                        Text(
                                                          'Note: ${item.catatan}',
                                                          style: TextStyle(
                                                            fontSize: 11.sp,
                                                            color:
                                                                Colors.orange,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  CurrencyFormatter.format(
                                                    item.subtotal,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.sp,
                                                    decoration: item.isCancelled
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                    color: item.isCancelled
                                                        ? Colors.grey
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                if (!item.isCancelled) ...[
                                                  SizedBox(width: 8),
                                                  InkWell(
                                                    onTap: () {
                                                      Navigator.pop(
                                                        sheetContext,
                                                      );
                                                      _showCancelDialog(
                                                        context,
                                                        order,
                                                        itemId: item.id,
                                                        itemName:
                                                            item.produkNama,
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        6,
                                                      ),
                                                      child: Icon(
                                                        Icons.delete_outline,
                                                        size: 20,
                                                        color: AppColors.error,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ] else
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text('Belum ada rincian pesanan'),
                              ),
                            ),
                          SizedBox(height: 12),
                          // Action Buttons
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        if (isBillPrinted) {
                                          AppSnackbar.showWarning(
                                            context,
                                            'Pesanan sudah di-bill. Tidak dapat menambah menu lagi.',
                                          );
                                          return;
                                        }
                                        setStateSheet(
                                          () => isProcessing = true,
                                        );
                                        await Future.delayed(
                                          const Duration(milliseconds: 100),
                                        );
                                        if (mounted)
                                          Navigator.pop(sheetContext);
                                        _navigateToPos(order);
                                      },
                                      icon: Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 18,
                                      ),
                                      label: Text('Tambah Menu'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isBillPrinted
                                            ? Colors.grey
                                            : AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!order.isPaid) ...[
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          setStateSheet(
                                            () => isProcessing = true,
                                          );
                                          await Future.delayed(
                                            const Duration(milliseconds: 100),
                                          );
                                          if (mounted)
                                            Navigator.pop(sheetContext);
                                          _navigateToPayment(order);
                                        },
                                        icon: Icon(
                                          Icons.payments_outlined,
                                          size: 18,
                                        ),
                                        label: Text('Bayar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _showPrintBatchesDialog(order, items);
                                      },
                                      icon: Icon(
                                        Icons.soup_kitchen_rounded,
                                        size: 18,
                                        color: Colors.orange.shade700,
                                      ),
                                      label: Text(
                                        'Batch',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        side: BorderSide(
                                          color: Colors.orange.shade700,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        AppDialog.show(
                                          context: context,
                                          title: 'Konfirmasi Cetak Bill',
                                          message:
                                              'Setelah Bill dicetak, pesanan ini tidak dapat diubah atau ditambah menu lagi.\n\nApakah Anda yakin ingin mencetak bill sekarang?',
                                          confirmText: 'Ya, Cetak Bill',
                                          cancelText: 'Batal',
                                          onConfirm: () async {
                                            Navigator.pop(
                                              context,
                                            ); // close dialog
                                            final repo = ref.read(
                                              orderRepositoryProvider,
                                            );
                                            await repo.markOrderBillPrinted(
                                              order.id,
                                            );
                                            if (isDineIn &&
                                                order.tableId != null) {
                                              await repo.markTableBillPrinted(
                                                order.tableId!,
                                              );
                                            }

                                            // Update local state so UI refreshes immediately
                                            setStateSheet(() {
                                              isBillPrinted = true;
                                            });

                                            ref
                                                .read(
                                                  orderNotifierProvider
                                                      .notifier,
                                                )
                                                .loadActiveOrdersMap();

                                            final activeUser = ref.read(
                                              authSessionProvider,
                                            );
                                            final printerState = ref.read(
                                              printerNotifierProvider,
                                            );
                                            final cashierPrinterList =
                                                printerState.configuredPrinters
                                                    .where((p) => p.isCashier)
                                                    .toList();
                                            final cashierPrinter =
                                                cashierPrinterList.isNotEmpty
                                                ? cashierPrinterList.first
                                                : null;

                                            final textPreview =
                                                await ReceiptGenerator.formatBillTextPreview(
                                                  order: order,
                                                  items: items,
                                                  cashierNama:
                                                      order.cashierNama ??
                                                      activeUser?.nama,
                                                  charsPerLine:
                                                      cashierPrinter
                                                          ?.effectiveCharsPerLine ??
                                                      32,
                                                );

                                            if (!sheetContext.mounted) return;

                                            // Mark as billed
                                            await ref
                                                .read(
                                                  orderNotifierProvider
                                                      .notifier,
                                                )
                                                .markOrderAsBilled(order.id);

                                            AppReceiptPreviewModal.show(
                                              sheetContext,
                                              title: 'BILL SEMENTARA',
                                              receiptTextPreview: textPreview,
                                              printerType: 'cashier',
                                              onGeneratePdf: () =>
                                                  PdfReceiptGenerator.generateBillPdf(
                                                    order: order,
                                                    items: items,
                                                    cashierNama:
                                                        order.cashierNama ??
                                                        activeUser?.nama,
                                                  ),
                                              onGenerateEscPosBytes: () =>
                                                  ReceiptGenerator.generateBillReceipt(
                                                    order: order,
                                                    items: items,
                                                    cashierNama:
                                                        order.cashierNama ??
                                                        activeUser?.nama,
                                                    paperSize:
                                                        cashierPrinter
                                                            ?.escPosPaperSize ??
                                                        PaperSize.mm58,
                                                    charsPerLine:
                                                        cashierPrinter
                                                            ?.effectiveCharsPerLine ??
                                                        32,
                                                    autoCut:
                                                        cashierPrinter
                                                            ?.autoCut ??
                                                        false,
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                      icon: Icon(
                                        Icons.receipt_long_rounded,
                                        size: 18,
                                        color: AppColors.secondary,
                                      ),
                                      label: Text(
                                        'Cetak Bill',
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        side: const BorderSide(
                                          color: AppColors.secondary,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isDineIn && table != null) ...[
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isProcessing
                                            ? null
                                            : () async {
                                                setStateSheet(
                                                  () => isProcessing = true,
                                                );
                                                await Future.delayed(
                                                  const Duration(
                                                    milliseconds: 100,
                                                  ),
                                                );
                                                if (mounted)
                                                  Navigator.pop(sheetContext);
                                                _handleMoveTable(
                                                  context,
                                                  table!,
                                                  order,
                                                );
                                              },
                                        icon: Icon(
                                          Icons.move_up_rounded,
                                          size: 18,
                                        ),
                                        label: Text('Pindah Meja'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.secondary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
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
                    ),
            );
          },
        );
      },
    );
  }

  void _showCancelDialog(
    BuildContext context,
    OrderModel activeOrder, {
    String? batchId,
    String? itemId,
    String? itemName,
  }) {
    final reasonController = TextEditingController();
    final pinController = TextEditingController();
    final isBatch = batchId != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        String? dialogErrorMessage;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                isBatch ? 'Batalkan Batch' : 'Batalkan $itemName',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Alasan Pembatalan:', style: AppTypography.labelLarge),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan alasan pembatalan...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text('Otorisasi Owner (PIN):', style: AppTypography.labelLarge),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        hintText: '6 Digit PIN Owner',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (dialogErrorMessage != null) ...[
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          dialogErrorMessage!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Tutup',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          final pin = pinController.text.trim();

                          if (reason.isEmpty) {
                            setDialogState(
                              () => dialogErrorMessage =
                                  'Harap isi alasan pembatalan.',
                            );
                            return;
                          }
                          if (pin.length != 6) {
                            setDialogState(
                              () => dialogErrorMessage =
                                  'Harap isi 6 digit PIN Owner.',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            dialogErrorMessage = null;
                          });

                          try {
                            const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
                            var bytes = utf8.encode(pin + salt);
                            final hashedPin = sha256.convert(bytes).toString();

                            // 1. Cek Local PIN (PIN Owner saat setup/login)
                            final storage =
                                ref.read(secureStorageServiceProvider);
                            final savedLocalPin = await storage.getLocalPIN();
                            bool isAuthorized = savedLocalPin != null &&
                                (savedLocalPin == hashedPin ||
                                    savedLocalPin == pin);

                            // 2. Cek Master PIN Keamanan jika belum authorized
                            if (!isAuthorized) {
                              try {
                                isAuthorized = await ref
                                    .read(securityRepositoryProvider)
                                    .validateMasterPin(pin);
                              } catch (_) {}
                            }

                            // 3. Cek Kasir bertipe Owner jika belum authorized
                            if (!isAuthorized) {
                              try {
                                final cashierRepo =
                                    ref.read(cashierRepositoryProvider);
                                final cashier = await cashierRepo
                                    .getCashierByPin(hashedPin);
                                if (cashier != null && cashier.isOwner == 1) {
                                  isAuthorized = true;
                                }
                              } catch (_) {}
                            }

                            // 4. Cek jika sesi aktif adalah Owner
                            if (!isAuthorized) {
                              final authUser = ref.read(authSessionProvider);
                              if (authUser != null && authUser.isOwner) {
                                isAuthorized = true;
                              }
                            }

                            if (!isAuthorized) {
                              setDialogState(() {
                                isSubmitting = false;
                                dialogErrorMessage =
                                    'Otorisasi gagal! PIN salah atau bukan Owner.';
                              });
                              return;
                            }

                            // Otorisasi Sukses -> Tutup Dialog & Proses Pembatalan
                            Navigator.pop(dialogContext);

                            if (isBatch) {
                              await ref
                                  .read(orderNotifierProvider.notifier)
                                  .cancelOrderBatch(batchId, reason);
                            } else if (itemId != null) {
                              await ref
                                  .read(orderNotifierProvider.notifier)
                                  .cancelOrderItem(itemId, reason);
                            }

                            if (context.mounted) {
                              AppSnackbar.showSuccess(
                                context,
                                'Pembatalan berhasil.',
                              );
                              ref
                                  .read(tableNotifierProvider.notifier)
                                  .loadTables();
                              ref
                                  .read(orderNotifierProvider.notifier)
                                  .loadActiveOrdersMap();
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogErrorMessage =
                                  'Gagal memproses pembatalan: $e';
                            });
                          }
                        },
                  child: isSubmitting
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Batalkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleMoveTable(
    BuildContext context,
    TableModel sourceTable,
    OrderModel activeOrder,
  ) {
    final tableState = ref.read(tableNotifierProvider);
    final emptyTables = tableState.allTables.where((t) => t.isEmpty).toList();

    if (emptyTables.isEmpty) {
      AppSnackbar.showWarning(
        context,
        'Tidak ada meja kosong yang tersedia untuk dipindahkan.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width > 500
                ? 400
                : MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pindah Meja - ${sourceTable.nama}',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: emptyTables.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final targetTable = emptyTables[index];
                      return ListTile(
                        leading: Icon(
                          Icons.table_restaurant_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(targetTable.nama),
                        subtitle: Text('Nomor: ${targetTable.nomor}'),
                        onTap: () async {
                          Navigator.pop(context);

                          final orderRepo = ref.read(orderRepositoryProvider);
                          try {
                            await orderRepo.transferOrderTable(
                              activeOrder.id,
                              sourceTable.id,
                              targetTable.id,
                              targetTable.nama,
                              targetTable.nomor,
                            );

                            ref
                                .read(tableNotifierProvider.notifier)
                                .loadTables();
                            ref
                                .read(orderNotifierProvider.notifier)
                                .loadActiveOrdersMap();

                            if (context.mounted) {
                              AppSnackbar.showSuccess(
                                context,
                                'Berhasil memindahkan pesanan ke ${targetTable.nama}',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppSnackbar.showError(
                                context,
                                'Gagal memindahkan meja: $e',
                              );
                            }
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

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider);
    final allDrafts = orderState.allDraftOrders;

    final dineInCount = allDrafts.where((o) => o.orderType == 'dine_in').length;
    final takeawayCount = allDrafts
        .where((o) => o.orderType == 'take_away')
        .length;

    final filteredDraftOrders = allDrafts.where((order) {
      if (_orderFilter == 'dine_in') return order.orderType == 'dine_in';
      if (_orderFilter == 'take_away') return order.orderType == 'take_away';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Transaksi POS - Pesanan Baru & Aktif'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: _isNavigatingToDineIn
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: AppLoading(message: 'Memuat...'),
                                ),
                              )
                            : Column(
                                children: [
                                  Icon(
                                    Icons.restaurant_rounded,
                                    size: 38,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Dine-In',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Makan di tempat (Pilih Meja)',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.sp,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: InkWell(
                      onTap: _handleTakeAwaySelected,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.secondary,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_bag_rounded,
                              size: 38,
                              color: AppColors.secondary,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Takeaway',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Bungkus / Online Food',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.l),

              // Bottom Section Header: Daftar Pesanan Aktif
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Daftar Pesanan Aktif (${allDrafts.length})',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (allDrafts.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Draft / Open Bill',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: AppSpacing.s),

              // Filter Chips: Semua / Dine-In / Takeaway
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'Semua',
                      'all',
                      allDrafts.length,
                      AppColors.primary,
                      Icons.list_alt_rounded,
                    ),
                    SizedBox(width: 8),
                    _buildFilterChip(
                      'Dine-In',
                      'dine_in',
                      dineInCount,
                      Colors.blue.shade700,
                      Icons.restaurant_rounded,
                    ),
                    SizedBox(width: 8),
                    _buildFilterChip(
                      'Takeaway',
                      'take_away',
                      takeawayCount,
                      Colors.orange.shade800,
                      Icons.shopping_bag_rounded,
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.m),

              // Draft Orders List
              Expanded(
                child: orderState.isLoading && allDrafts.isEmpty
                    ? const AppLoading(message: 'Memuat pesanan aktif...')
                    : filteredDraftOrders.isEmpty
                    ? AppEmptyState(
                        title: _orderFilter == 'all'
                            ? 'Belum Ada Pesanan Aktif'
                            : (_orderFilter == 'dine_in'
                                  ? 'Tidak Ada Pesanan Dine-In Aktif'
                                  : 'Tidak Ada Pesanan Takeaway Aktif'),
                        description:
                            'Pilih "Dine In" atau "Take Away" di atas untuk membuat pesanan baru.',
                        icon: Icons.receipt_long_outlined,
                      )
                    : ListView.separated(
                        itemCount: filteredDraftOrders.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: AppSpacing.s),
                        itemBuilder: (context, index) {
                          final order = filteredDraftOrders[index];
                          final isDineIn = order.orderType == 'dine_in';
                          final formattedTime = DateFormat(
                            'HH:mm',
                          ).format(order.createdAt);

                          return AppCard(
                            onTap: _loadingOrderId != null
                                ? null
                                : () async {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _loadingOrderId = order.id);
                                    // Mencegah animasi bottom sheet bertabrakan dengan dialog yang sedang menutup
                                    await Future.delayed(
                                      const Duration(milliseconds: 300),
                                    );
                                    await _showOrderActionBottomSheet(order);
                                    if (mounted)
                                      setState(() => _loadingOrderId = null);
                                  },
                            padding: const EdgeInsets.all(12),
                            color: order.isBillPrinted
                                ? Colors.amber.shade50
                                : null,
                            borderSide: order.isBillPrinted
                                ? BorderSide(
                                    color: Colors.amber.shade400,
                                    width: 1.5,
                                  )
                                : null,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: order.isBillPrinted
                                        ? Colors.amber.shade100
                                        : (isDineIn
                                              ? AppColors.primary.withValues(
                                                  alpha: 0.1,
                                                )
                                              : AppColors.secondary.withValues(
                                                  alpha: 0.1,
                                                )),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    order.isBillPrinted
                                        ? Icons.receipt_long_rounded
                                        : (isDineIn
                                              ? Icons.table_restaurant_rounded
                                              : Icons.shopping_bag_rounded),
                                    color: order.isBillPrinted
                                        ? Colors.amber.shade900
                                        : (isDineIn
                                              ? AppColors.primary
                                              : AppColors.secondary),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 2,
                                        children: [
                                          Text(
                                            order.nomorOrder,
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.sp,
                                                ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDineIn
                                                  ? Colors.blue.shade50
                                                  : Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isDineIn
                                                  ? 'Meja: ${order.tableNama ?? order.tableNomor ?? '-'}'
                                                  : 'Take Away (${order.takeAwaySubType == 'online_food' ? 'Online${order.onlinePlatform != null ? " - ${order.onlinePlatform}" : ""}' : 'Reguler'})',
                                              style: TextStyle(
                                                color: isDineIn
                                                    ? Colors.blue.shade800
                                                    : Colors.orange.shade800,
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (order.isBillPrinted)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.amber.shade600,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.receipt_rounded,
                                                    size: 10,
                                                    color:
                                                        Colors.amber.shade900,
                                                  ),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'SUDAH DI-BILL',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.amber.shade900,
                                                      fontSize: 9.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  order.paymentStatus ==
                                                      'unpaid'
                                                  ? Colors.red.shade50
                                                  : (order.paymentStatus ==
                                                            'billed'
                                                        ? Colors.orange.shade50
                                                        : Colors.green.shade50),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color:
                                                    order.paymentStatus ==
                                                        'unpaid'
                                                    ? Colors.red.shade200
                                                    : (order.paymentStatus ==
                                                              'billed'
                                                          ? Colors
                                                                .orange
                                                                .shade200
                                                          : Colors
                                                                .green
                                                                .shade200),
                                              ),
                                            ),
                                            child: Text(
                                              order.paymentStatus.toUpperCase(),
                                              style: TextStyle(
                                                color:
                                                    order.paymentStatus ==
                                                        'unpaid'
                                                    ? Colors.red.shade700
                                                    : (order.paymentStatus ==
                                                              'billed'
                                                          ? Colors
                                                                .orange
                                                                .shade800
                                                          : Colors
                                                                .green
                                                                .shade700),
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Waktu: $formattedTime • Pelanggan: ${order.customerName ?? 'Umum'}',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11.sp,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        CurrencyFormatter.format(
                                          order.grandTotal,
                                        ),
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                              fontSize: 13.sp,
                                            ),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    if (_loadingOrderId == order.id)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          right: 4,
                                        ),
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      )
                                    else
                                      Row(
                                        children: [
                                          Text(
                                            'Buka Kasir',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 14,
                                            color: AppColors.primary,
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
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    int count,
    Color activeColor,
    IconData icon,
  ) {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : activeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : activeColor.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.sp,
              color: isSelected ? Colors.white : activeColor,
            ),
            SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.sp,
                color: isSelected ? Colors.white : activeColor,
              ),
            ),
            SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : activeColor.withValues(alpha: 0.15),
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

  Future<void> _showPrintBatchesDialog(
    OrderModel order,
    List<OrderItemModel> items,
  ) async {
    final repo = ref.read(orderRepositoryProvider);

    int unprintedCount = 0;
    List<OrderItemModel> unprintedItems = [];
    for (var item in items) {
      if (item.statusCetak == 0 && !item.isCancelled) {
        unprintedCount += item.qty.toInt();
        unprintedItems.add(item);
      }
    }

    int existingBatchCount = 0;
    try {
      final batches = await repo.getPrintBatches(order.id);
      existingBatchCount = batches.length;
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.94;
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: dialogWidth,
              padding: const EdgeInsets.all(20),
              child: isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: AppLoading(message: 'Memproses batch dapur...'),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.soup_kitchen_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Struk Batch Dapur',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Pilih batch pesanan yang ingin dikirim / dicetak ke printer dapur:',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),

                        if (unprintedCount > 0) ...[
                          Material(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                'Kirim Batch #${existingBatchCount + 1} ke Dapur',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              subtitle: Text(
                                'Ada +$unprintedCount item baru yang belum dikirim',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              onTap: () async {
                                setStateDialog(() => isProcessing = true);
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                if (mounted) {
                                  await _printNewKitchenBatch(
                                    order,
                                    unprintedItems,
                                  );
                                }
                                if (mounted) Navigator.pop(dialogCtx);
                              },
                            ),
                          ),
                          SizedBox(height: 14),
                        ],

                        if (existingBatchCount > 0) ...[
                          Text(
                            'Batch Pesanan Sebelumnya:',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 8),
                          ...List.generate(existingBatchCount, (index) {
                            final bNum = index + 1;
                            final bLabel = bNum == 1
                                ? 'Batch #1 (Pesanan Awal)'
                                : 'Batch #$bNum (Pesanan Tambahan)';
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 6),
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(
                                  color: AppColors.divider,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.print_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                title: Text(
                                  bLabel,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.print_rounded,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                                onTap: () async {
                                  setStateDialog(() => isProcessing = true);
                                  await Future.delayed(
                                    const Duration(milliseconds: 100),
                                  );
                                  if (mounted) {
                                    await _reprintKitchenBatch(order, bNum);
                                  }
                                },
                              ),
                            );
                          }),
                          SizedBox(height: 4),
                          Card(
                            elevation: 0,
                            color: AppColors.success.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.receipt_long_rounded,
                                size: 20,
                                color: AppColors.success,
                              ),
                              title: Text(
                                'Cetak Rekap Dapur (Semua Menu)',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              onTap: () async {
                                setStateDialog(() => isProcessing = true);
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                if (mounted) {
                                  await _reprintKitchenBatch(order, 0);
                                }
                              },
                            ),
                          ),
                        ] else if (unprintedCount == 0) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'Belum ada batch pesanan tersimpan untuk meja ini.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text('Tutup'),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _printNewKitchenBatch(OrderModel order, List<OrderItemModel> unprintedItems) async {
    try {
      final repo = ref.read(orderRepositoryProvider);
      
      final newBatchId = await repo.recordPrintBatch(order.id);
      await repo.markItemsAsPrinted(order.id, newBatchId);

      final waveInfo = '#${(await repo.getPrintBatches(order.id)).length} (BARU)';

      await ref.read(printerNotifierProvider.notifier).loadPrinters();
      final printerState = ref.read(printerNotifierProvider);
      final kitchenPrinters = printerState.configuredPrinters
          .where((p) => p.isKitchen)
          .toList();
      final targetPrinter = kitchenPrinters.isNotEmpty
          ? kitchenPrinters.first
          : (printerState.configuredPrinters.isNotEmpty
                ? printerState.configuredPrinters.first
                : null);

      final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
        order: order,
        itemsToPrint: unprintedItems,
        waveInfo: waveInfo,
        paperSize: targetPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: targetPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: targetPrinter?.autoCut ?? false,
      );

      if (!mounted) return;

      if (targetPrinter != null) {
        await ref
            .read(printerNotifierProvider.notifier)
            .printBytes(targetPrinter, receiptBytes);
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Struk Dapur $waveInfo berhasil dicetak.',
          );
          ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
        }
      } else {
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Simulasi Struk Dapur $waveInfo (Printer tidak terhubung).',
          );
          ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
        }
      }
    } catch (e) {
      if (mounted)
        AppSnackbar.showError(context, 'Gagal kirim batch dapur: $e');
    }
  }

  Future<void> _reprintKitchenBatch(OrderModel order, int batchNumber) async {
    try {
      final items = await ref
          .read(orderRepositoryProvider)
          .getOrderItems(order.id);
      List<OrderItemModel> itemsToPrint = [];

      if (batchNumber == 0) {
        itemsToPrint = items.where((i) => !i.isCancelled).toList();
      } else {
        final batches = await ref
            .read(orderRepositoryProvider)
            .getPrintBatches(order.id);
        if (batches.length >= batchNumber) {
          final targetBatchId = batches[batchNumber - 1]['id'] as String;
          itemsToPrint = items
              .where((i) => i.printBatchId == targetBatchId && !i.isCancelled)
              .toList();
        }
      }

      if (!mounted) return;

      if (itemsToPrint.isEmpty) {
        AppSnackbar.showWarning(context, 'Tidak ada item menu pada batch ini.');
        return;
      }

      final waveInfo = batchNumber == 0
          ? '[REKAP DAPUR]'
          : (batchNumber == 1
                ? '#1 (Pesanan Awal - CETAK ULANG)'
                : '#$batchNumber (Tambahan - CETAK ULANG)');

      await ref.read(printerNotifierProvider.notifier).loadPrinters();
      final printerState = ref.read(printerNotifierProvider);
      final kitchenPrinters = printerState.configuredPrinters
          .where((p) => p.isKitchen)
          .toList();
      final targetPrinter = kitchenPrinters.isNotEmpty
          ? kitchenPrinters.first
          : (printerState.configuredPrinters.isNotEmpty
                ? printerState.configuredPrinters.first
                : null);

      final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
        order: order,
        itemsToPrint: itemsToPrint,
        waveInfo: waveInfo,
        paperSize: targetPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: targetPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: targetPrinter?.autoCut ?? false,
      );

      if (!mounted) return;

      if (targetPrinter != null) {
        await ref
            .read(printerNotifierProvider.notifier)
            .printBytes(targetPrinter, receiptBytes);
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Struk Dapur $waveInfo berhasil dicetak.',
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Simulasi Struk Dapur $waveInfo (Printer tidak terhubung).',
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal mencetak ulang dapur: $e');
      }
    }
  }
}
