import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/di/providers.dart';
import '../../../table/application/table_notifier.dart';
import '../../../table/domain/models/table.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../screens/pos_screen.dart';
import '../screens/payment_screen.dart';

class TableOrderDetailSheet {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    TableModel table,
    dynamic activeOrder,
  ) async {
    final hasOrder = activeOrder != null;
    final isDraft = hasOrder && (activeOrder as OrderModel).isDraft;
    final isPaid = hasOrder && (activeOrder as OrderModel).isPaid;
    final repo = ref.read(orderRepositoryProvider);

    List<OrderItemModel> items = [];
    List<Map<String, dynamic>> batches = [];

    if (hasOrder) {
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

    if (!context.mounted) return;

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
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              padding: const EdgeInsets.all(AppSpacing.m),
              child: isProcessing ? const Padding(
                padding: EdgeInsets.all(32.0),
                child: AppLoading(message: 'Memproses...'),
              ) : Column(
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
                        style: AppTypography.titleMedium.copyWith(fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                      if (activeOrder?.customerName != null && activeOrder.customerName.isNotEmpty)
                        Text(
                          'Atas Nama: ${activeOrder.customerName}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (!hasOrder
                          ? AppColors.success
                          : isDraft
                              ? AppColors.warning
                              : Colors.blue)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: (!hasOrder
                              ? AppColors.success
                              : isDraft
                                  ? AppColors.warning
                                  : Colors.blue)
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      !hasOrder
                          ? Icons.check_circle_outline_rounded
                          : isDraft
                              ? Icons.hourglass_empty_rounded
                              : Icons.restaurant_rounded,
                      color: !hasOrder
                          ? AppColors.success
                          : isDraft
                              ? AppColors.warning
                              : Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !hasOrder
                                ? 'Status: Kosong / Tersedia'
                                : isDraft
                                    ? 'Status: Open Bill (Belum Dibayar)'
                                    : 'Status: Terisi (Lunas di Awal / Sedang Makan)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: !hasOrder
                                  ? const Color(0xFF14532D)
                                  : isDraft
                                      ? const Color(0xFF78350F)
                                      : const Color(0xFF1E3A8A),
                            ),
                          ),
                          if (activeOrder != null) ...[
                            Text('No. Order: ${activeOrder.nomorOrder}', style: TextStyle(fontSize: 12.sp)),
                            Text(
                              'Total Tagihan: ${CurrencyFormatter.format(activeOrder.grandTotal)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: AppColors.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              // Items List Grouped by Batch
              if (groupedItems.isNotEmpty) ...[
                Text('Rincian Pesanan per Batch:', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
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
                            InkWell(
                              onTap: () {
                                setStateSheet(() {
                                  if (expandedBatches.contains(batchTitle)) {
                                    expandedBatches.remove(batchTitle);
                                  } else {
                                    expandedBatches.add(batchTitle);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.vertical(
                                    top: const Radius.circular(9),
                                    bottom: Radius.circular(expandedBatches.contains(batchTitle) ? 0 : 9),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.soup_kitchen_rounded, size: 16, color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      batchTitle,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppColors.primary),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${batchItemList.length} Menu',
                                      style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      expandedBatches.contains(batchTitle) ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (expandedBatches.contains(batchTitle))
                              ...batchItemList.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('${item.qty}x', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.produkNama, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp)),
                                        if (item.hasModifiers) ...[
                                          const SizedBox(height: 2),
                                          ...item.selectedModifiers.map((m) => Padding(
                                            padding: const EdgeInsets.only(bottom: 1),
                                            child: Text(
                                              '+ ${m.groupName}: ${m.optionName}${m.harga > 0 ? ' (+${CurrencyFormatter.format(m.harga)})' : ''}',
                                              style: TextStyle(fontSize: 10.5.sp, color: AppColors.primary, fontWeight: FontWeight.w500),
                                            ),
                                          )),
                                        ],
                                        if (item.catatan != null && item.catatan!.isNotEmpty)
                                          Text('Note: ${item.catatan}', style: TextStyle(fontSize: 11.sp, color: Colors.orange, fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
                                  ),
                                  SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Batalkan Menu (Void Item)',
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showVoidItemDialog(context, ref, activeOrder.id, item, table);
                                    },
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
                Expanded(
                  child: Center(
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
                          onPressed: isProcessing ? null : () async {
                            setStateSheet(() => isProcessing = true);
                            await Future.delayed(const Duration(milliseconds: 100));
                            if (context.mounted) Navigator.pop(context);
                            navigateToPos(context, ref, table);
                          },
                          icon: Icon(Icons.shopping_cart_outlined, size: 18),
                          label: Text(hasOrder ? 'Tambah Menu' : 'Pesan Baru'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasOrder) ...[
                    if (isDraft && !isPaid) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isProcessing ? null : () async {
                                setStateSheet(() => isProcessing = true);
                                await Future.delayed(const Duration(milliseconds: 100));
                                if (context.mounted) Navigator.pop(context);
                                navigateToPayment(context, ref, table, activeOrder);
                              },
                              icon: Icon(Icons.payments_outlined, size: 18),
                              label: Text('Bayar Tagihan (Open Bill)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isPaid) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isProcessing ? null : () async {
                                setStateSheet(() => isProcessing = true);
                                await Future.delayed(const Duration(milliseconds: 100));
                                if (context.mounted) Navigator.pop(context);
                                handleClearTable(context, ref, table, activeOrder);
                              },
                              icon: Icon(Icons.cleaning_services_rounded, size: 18),
                              label: Text('Bersihkan Meja'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isProcessing ? null : () async {
                              setStateSheet(() => isProcessing = true);
                              await Future.delayed(const Duration(milliseconds: 100));
                              if (context.mounted) Navigator.pop(context);
                              handleMoveTable(context, ref, table, activeOrder);
                            },
                            icon: Icon(Icons.move_up_rounded, size: 18),
                            label: Text('Pindah Meja'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              handleReprintKitchenTicket(context, ref, activeOrder, table);
                            },
                            icon: Icon(Icons.print_rounded, size: 18),
                            label: Text('Cetak Ulang (Reprint)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.primary,
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
      },
    );
  }

  static Future<void> navigateToPos(BuildContext context, WidgetRef ref, TableModel table) async {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productState = ref.read(productNotifierProvider);

    orderNotifier.selectTable(table);

    if (table.isOccupied) {
      await orderNotifier.loadActiveOrderForTable(table.id);
      final orderState = ref.read(orderNotifierProvider);
      
      if (orderState.activeOrder != null) {
        cartNotifier.loadDraftItems(orderState.activeOrderItems, productState.allProducts, orderState.activePrintBatches);
      } else {
        cartNotifier.clear();
      }
    } else {
      cartNotifier.clear();
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PosScreen()),
    ).then((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  static Future<void> navigateToPayment(BuildContext context, WidgetRef ref, TableModel table, dynamic activeOrder) async {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productState = ref.read(productNotifierProvider);

    orderNotifier.selectTable(table);
    if (table.isOccupied) {
      await orderNotifier.loadActiveOrderForTable(table.id);
      final orderState = ref.read(orderNotifierProvider);
      
      if (orderState.activeOrder != null) {
        cartNotifier.loadDraftItems(orderState.activeOrderItems, productState.allProducts, orderState.activePrintBatches);
      } else {
        cartNotifier.clear();
      }
    } else {
      cartNotifier.clear();
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentScreen()),
    ).then((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  static Future<void> handleReprintKitchenTicket(BuildContext context, WidgetRef ref, dynamic activeOrder, TableModel table) async {
    if (activeOrder == null) return;
    ref.read(orderNotifierProvider.notifier).selectTable(table);
    await ref.read(orderNotifierProvider.notifier).loadActiveOrderForTable(table.id);
    final success = await ref.read(orderNotifierProvider.notifier).reprintKitchenTicket(activeOrder.id);
    if (!context.mounted) return;
    if (success) {
      AppSnackbar.showSuccess(context, 'Tiket dapur (Reprint) berhasil dicetak dengan watermark JANGAN DIMASAK ULANG.');
    } else {
      AppSnackbar.showError(context, 'Gagal mencetak ulang tiket dapur.');
    }
  }

  static Future<void> handleClearTable(BuildContext context, WidgetRef ref, TableModel table, dynamic activeOrder) async {
    if (activeOrder == null) return;
    try {
      await ref.read(orderRepositoryProvider).completeOrder(activeOrder.id, tableId: table.id);
      if (!context.mounted) return;
      AppSnackbar.showSuccess(context, 'Meja ${table.nama} berhasil dibersihkan.');
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.showError(context, 'Gagal membersihkan meja: $e');
    }
  }

  static void handleMoveTable(BuildContext context, WidgetRef ref, TableModel sourceTable, dynamic activeOrder) {
    final tableState = ref.read(tableNotifierProvider);
    final emptyTables = tableState.allTables.where((t) => t.isEmpty).toList();

    if (emptyTables.isEmpty) {
      AppSnackbar.showWarning(context, 'Tidak ada meja kosong yang tersedia untuk dipindahkan.');
      return;
    }

    showDialog(
      context: context,
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
                  'Pindah Meja - ${sourceTable.nama}',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
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
                        leading: Icon(Icons.table_restaurant_rounded, color: AppColors.primary),
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

                            ref.read(tableNotifierProvider.notifier).loadTables();
                            ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();

                            if (context.mounted) {
                              AppSnackbar.showSuccess(context, 'Berhasil memindahkan pesanan ke ${targetTable.nama}');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppSnackbar.showError(context, 'Gagal memindahkan meja: $e');
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Batal'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showVoidItemDialog(BuildContext context, WidgetRef ref, String orderId, OrderItemModel item, TableModel table) {
    final pinController = TextEditingController();
    final reasonController = TextEditingController(text: 'Dibatalkan pelanggan');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Void Menu: ${item.produkNama}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batalkan item "${item.produkNama}" (${item.qty}x)? Masukkan PIN Kasir/Manager dan Alasan.',
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
                ),
                SizedBox(height: 16),
                AppTextField(
                  controller: reasonController,
                  labelText: 'Alasan Pembatalan',
                  hintText: 'Misal: Salah pesan / Habis',
                  prefixIcon: Icons.edit_note_rounded,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Alasan harus diisi' : null,
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: pinController,
                  labelText: 'PIN Master / Pemilik',
                  hintText: 'Masukkan PIN 6 digit',
                  prefixIcon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  validator: (val) => val == null || val.length != 6 ? 'PIN harus 6 digit' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final voidService = ref.read(voidOrderServiceProvider);
                  try {
                    final success = await voidService.voidOrderItem(
                      masterOrderId: orderId,
                      orderItemId: item.id,
                      qtyToVoid: item.qty,
                      reason: reasonController.text.trim(),
                      managerPin: pinController.text.trim(),
                    );

                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      if (success) {
                        AppSnackbar.showSuccess(context, 'Berhasil membatalkan menu "${item.produkNama}"');
                        ref.read(tableNotifierProvider.notifier).loadTables();
                        ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
                        await ref.read(orderNotifierProvider.notifier).loadActiveOrderForTable(table.id);
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackbar.showError(context, e.toString().replaceAll('Exception: ', ''));
                    }
                  }
                }
              },
              child: Text('Batalkan Menu'),
            ),
          ],
        );
      },
    );
  }
}
