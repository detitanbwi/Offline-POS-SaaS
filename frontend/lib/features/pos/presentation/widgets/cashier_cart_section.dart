import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';

import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../screens/payment_screen.dart';
import '../../../table/application/table_notifier.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../../printer/domain/models/printer_config.dart';
import '../../../../core/utils/receipt_generator.dart';

class CashierCartSection extends ConsumerStatefulWidget {
  final VoidCallback onSaveDraftCompleted;

  const CashierCartSection({
    super.key,
    required this.onSaveDraftCompleted,
  });

  @override
  ConsumerState<CashierCartSection> createState() => _CashierCartSectionState();
}

class _CashierCartSectionState extends ConsumerState<CashierCartSection> {
  final _appTotalController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final orderState = ref.read(orderNotifierProvider);
    final total = orderState.onlinePlatformTotal ?? orderState.activeOrder?.onlinePlatformTotal;
    if (total != null && total > 0) {
      _appTotalController.text = CurrencyFormatter.formatNumber(total);
      if (orderState.onlinePlatformTotal == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(orderNotifierProvider.notifier).setOnlinePlatformTotal(total);
        });
      }
    }
  }

  @override
  void dispose() {
    _appTotalController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveDraft() async {
    final cartState = ref.read(cartNotifierProvider);
    if (cartState.items.isEmpty) {
      AppSnackbar.showWarning(context, 'Keranjang masih kosong!');
      return;
    }

    final printChoice = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.soup_kitchen_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Simpan Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Apakah Anda ingin mengirim / mencetak nota pesanan ini ke dapur?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Ya, Kirim Dapur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(dialogCtx, true),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Tidak, Hanya Simpan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => Navigator.pop(dialogCtx, null),
                child: const Text('Batal', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );

    if (printChoice == null) return;
    await _handleSaveDraftWithKitchenPrint(printChoice);
  }

  Future<void> _handleSaveDraftWithKitchenPrint(bool printChoice) async {
    final cartState = ref.read(cartNotifierProvider);
    if (cartState.items.isEmpty) {
      AppSnackbar.showWarning(context, 'Keranjang masih kosong!');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final orderNotifier = ref.read(orderNotifierProvider.notifier);

      final result = await orderNotifier.saveCurrentOrderDraft(
        cartState.items,
        cartState.subtotal,
        cartState.taxRate,
        cartState.taxAmount,
        cartState.grandTotal,
        printToKitchen: printChoice,
      );

      if (!mounted) return;

      if (result != null) {
        AppSnackbar.showSuccess(
          context,
          printChoice ? 'Pesanan disimpan & dikirim ke dapur!' : 'Pesanan berhasil disimpan!',
        );
        ref.read(orderNotifierProvider.notifier).resetOrder();
        ref.read(cartNotifierProvider.notifier).clear();
        widget.onSaveDraftCompleted();
      } else {
        final err = ref.read(orderNotifierProvider).errorMessage;
        AppSnackbar.showError(context, err ?? 'Gagal menyimpan pesanan. Pastikan meja atau tipe pesanan telah dipilih.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal menyimpan pesanan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handlePrintBill() async {
    final cartState = ref.read(cartNotifierProvider);
    final orderState = ref.read(orderNotifierProvider);

    if (cartState.items.isEmpty) {
      AppSnackbar.showWarning(context, 'Keranjang masih kosong untuk dicetak bill!');
      return;
    }

    try {
      final printerNotifier = ref.read(printerNotifierProvider.notifier);
      final printerState = ref.read(printerNotifierProvider);
      
      final activePrinter = printerState.configuredPrinters.firstWhere(
        (p) => p.isCashier || p.type == 'cashier',
        orElse: () => printerState.configuredPrinters.isNotEmpty
            ? printerState.configuredPrinters.first
            : PrinterConfigModel(id: '', name: '', address: '', type: 'cashier', createdAt: DateTime.now()),
      );

      if (activePrinter.address.isEmpty) {
        AppSnackbar.showWarning(context, 'Printer bluetooth belum terhubung / dikonfigurasi!');
        return;
      }

      final orderModel = orderState.activeOrder ??
          OrderModel(
            id: 'temp',
            nomorOrder: 'DRAFT',
            tableNama: orderState.selectedTable?.nama ?? 'Take Away',
            customerName: orderState.customerName ?? 'Umum',
            orderType: orderState.orderType,
            subtotal: cartState.subtotal,
            taxAmount: cartState.taxAmount,
            grandTotal: cartState.grandTotal,
            status: 'draft',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final orderItemsList = cartState.items
          .map((i) => OrderItemModel(
                id: '',
                orderId: orderModel.id,
                produkId: i.product.id,
                produkNama: i.product.nama,
                produkHarga: i.product.harga,
                qty: i.qty,
                subtotal: i.subtotal,
                catatan: i.catatan,
              ))
          .toList();

      final bytes = await ReceiptGenerator.generateBillReceipt(
        order: orderModel,
        items: orderItemsList,
        paperSize: activePrinter.escPosPaperSize,
        charsPerLine: activePrinter.effectiveCharsPerLine,
      );

      await printerNotifier.printBytes(activePrinter, bytes);

      // Update table status to 4 (Bill Dicetak) if Dine-In table
      final tableId = orderState.selectedTable?.id ?? orderState.activeOrder?.tableId;
      if (tableId != null && tableId.isNotEmpty && tableId != 'TABLE_TAKE_AWAY') {
        await ref.read(tableNotifierProvider.notifier).updateStatus(tableId, 4);
      }

      if (mounted) {
        AppSnackbar.showSuccess(context, 'Struk Bill Sementara berhasil dicetak! Status meja diperbarui (Bill Dicetak).');
        Navigator.popUntil(context, (route) => route.settings.name == '/order_hub' || route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal mencetak bill: $e');
      }
    }
  }

  void _handleGoToPayment() {
    final cartState = ref.read(cartNotifierProvider);
    if (cartState.items.isEmpty) {
      AppSnackbar.showWarning(context, 'Keranjang masih kosong!');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentScreen()),
    );
  }

  Future<void> _showPrintBatchesDialog() async {
    final cartState = ref.read(cartNotifierProvider);
    final orderState = ref.read(orderNotifierProvider);
    final order = orderState.activeOrder;

    int unprintedCount = 0;
    for (var item in cartState.items) {
      if (item.qty > item.initialSavedQty) {
        unprintedCount += (item.qty - item.initialSavedQty);
      }
    }

    int existingBatchCount = 0;
    if (order != null) {
      try {
        final repo = ref.read(orderRepositoryProvider);
        final batches = await repo.getPrintBatches(order.id);
        existingBatchCount = batches.length;
      } catch (_) {}
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.94;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.soup_kitchen_rounded, color: AppColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Struk Batch Dapur',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih batch pesanan yang ingin dikirim / dicetak ke printer dapur:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // 1. If unprinted items exist, show prominent action tile at top!
                if (unprintedCount > 0) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ),
                      title: Text(
                        'Kirim Batch #${existingBatchCount + 1} ke Dapur',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      subtitle: Text(
                        'Ada +$unprintedCount item baru yang belum dikirim',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                      onTap: () async {
                        Navigator.pop(dialogCtx);
                        if (mounted) {
                          await _handleSaveDraftWithKitchenPrint(true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. Existing Printed Batches
                if (existingBatchCount > 0) ...[
                  const Text(
                    'Batch Pesanan Sebelumnya:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(existingBatchCount, (index) {
                    final bNum = index + 1;
                    final bLabel = bNum == 1 ? 'Batch #1 (Pesanan Awal)' : 'Batch #$bNum (Pesanan Tambahan)';
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 6),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.print_rounded, size: 20, color: AppColors.primary),
                        title: Text(bLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.print_rounded, size: 20, color: AppColors.primary),
                        ),
                        onTap: () async {
                          Navigator.pop(dialogCtx);
                          if (mounted && order != null) {
                            await _reprintKitchenBatch(order, bNum);
                          }
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Card(
                    elevation: 0,
                    color: AppColors.success.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.success),
                      title: const Text('Cetak Rekap Dapur (Semua Menu)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                      onTap: () async {
                        Navigator.pop(dialogCtx);
                        if (mounted && order != null) {
                          await _reprintKitchenBatch(order, 0);
                        }
                      },
                    ),
                  ),
                ] else if (unprintedCount == 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'Belum ada batch pesanan tersimpan untuk meja ini.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Tutup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reprintKitchenBatch(OrderModel order, int batchNumber) async {
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

      if (!mounted) return;

      if (itemsToPrint.isEmpty) {
        AppSnackbar.showWarning(context, 'Tidak ada item menu pada batch ini.');
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

      if (!mounted) return;

      if (targetPrinter != null) {
        await ref.read(printerNotifierProvider.notifier).printBytes(targetPrinter, receiptBytes);
        if (mounted) {
          AppSnackbar.showSuccess(context, 'Struk Dapur $waveInfo berhasil dicetak.');
          Navigator.popUntil(context, (route) => route.settings.name == '/order_hub' || route.isFirst);
        }
      } else {
        if (mounted) {
          AppSnackbar.showSuccess(context, 'Simulasi Struk Dapur $waveInfo (Printer tidak terhubung).');
          Navigator.popUntil(context, (route) => route.settings.name == '/order_hub' || route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal mencetak ulang dapur: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartNotifierProvider);
    final orderState = ref.watch(orderNotifierProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final orderNotifier = ref.read(orderNotifierProvider.notifier);

    int unprintedCount = 0;
    for (var item in cartState.items) {
      if (item.qty > item.initialSavedQty) {
        unprintedCount += (item.qty - item.initialSavedQty);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                orderState.isTakeAway ? Icons.shopping_bag_rounded : Icons.table_restaurant_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  orderState.isTakeAway
                      ? (orderState.takeAwaySubType == 'online_food'
                          ? 'Take Away (${orderState.onlinePlatform ?? 'Online Food'})'
                          : 'Take Away (Reguler)')
                      : (orderState.selectedTable?.nama ?? orderState.activeOrder?.tableNama ?? 'Pesanan Meja'),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),

        Expanded(
          child: cartState.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'Keranjang Masih Kosong',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: orderState.activeOrder != null
                      ? ref.read(orderRepositoryProvider).getPrintBatches(orderState.activeOrder!.id)
                      : Future.value([]),
                  builder: (context, snapshot) {
                    final batches = snapshot.data ?? [];
                    final activeOrderItems = orderState.activeOrderItems.where((i) => !i.isCancelled).toList();

                    final Map<String, List<OrderItemModel>> batchItemsMap = {};
                    for (var b in batches) {
                      final bId = b['id'] as String;
                      batchItemsMap[bId] = [];
                    }

                    final List<OrderItemModel> unmappedSavedItems = [];
                    for (var item in activeOrderItems) {
                      if (item.printBatchId != null && batchItemsMap.containsKey(item.printBatchId)) {
                        batchItemsMap[item.printBatchId]!.add(item);
                      } else if (item.statusCetak == 1 || item.printBatchId != null) {
                        unmappedSavedItems.add(item);
                      }
                    }

                    final newItems = cartState.items.where((i) => i.qty > i.initialSavedQty || i.initialSavedQty == 0).toList();

                    return ListView(
                      children: [
                        // 1. Batch Baru (Belum Kirim Dapur)
                        if (newItems.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                title: Row(
                                  children: [
                                    const Icon(Icons.add_shopping_cart_rounded, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Batch Baru (Belum Kirim)',
                                      style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${newItems.length} menu baru',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                children: newItems.map((item) {
                                  final newQty = item.initialSavedQty > 0 ? item.qty - item.initialSavedQty : item.qty;
                                  final newSubtotal = item.product.harga * newQty;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.product.nama,
                                                style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                CurrencyFormatter.format(item.product.harga),
                                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            if (item.canDecrement)
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                                                color: AppColors.error,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                onPressed: () {
                                                  cartNotifier.updateQuantity(item.product.id, item.qty - 1);
                                                },
                                              )
                                            else
                                              const SizedBox(width: 32),
                                            Text(
                                              '$newQty',
                                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                                              color: AppColors.primary,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              onPressed: () {
                                                cartNotifier.updateQuantity(item.product.id, item.qty + 1);
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            CurrencyFormatter.format(newSubtotal),
                                            textAlign: TextAlign.right,
                                            style: AppTypography.titleMedium.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),

                        // 2. Individual Printed Batches
                        if (batches.isNotEmpty) ...[
                          for (int i = 0; i < batches.length; i++) ...[
                            Builder(
                              builder: (context) {
                                final bId = batches[i]['id'] as String;
                                var bItems = batchItemsMap[bId] ?? [];
                                if (i == 0 && unmappedSavedItems.isNotEmpty) {
                                  bItems = [...bItems, ...unmappedSavedItems];
                                }
                                if (bItems.isEmpty) return const SizedBox.shrink();

                                final bNum = i + 1;
                                final bTitle = bNum == 1 ? 'Batch #1 (Pesanan Awal)' : 'Batch #$bNum (Pesanan Tambahan)';
                                final bSubtotal = bItems.fold<double>(0, (sum, item) => sum + item.subtotal);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: newItems.isEmpty && i == batches.length - 1,
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.soup_kitchen_rounded, size: 16, color: AppColors.success),
                                          const SizedBox(width: 6),
                                          Text(
                                            bTitle,
                                            style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${bItems.length} menu • ${CurrencyFormatter.format(bSubtotal)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      children: bItems.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.produkNama,
                                                      style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${item.qty}x @ ${CurrencyFormatter.format(item.produkHarga)} (Tersimpan)',
                                                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: 70,
                                                child: Text(
                                                  CurrencyFormatter.format(item.subtotal),
                                                  textAlign: TextAlign.right,
                                                  style: AppTypography.titleMedium.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ] else if (cartState.items.any((i) => i.initialSavedQty > 0)) ...[
                          // Fallback if no batch record exists in database table
                          Builder(
                            builder: (context) {
                              final savedCartItems = cartState.items.where((i) => i.initialSavedQty > 0).toList();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    initiallyExpanded: newItems.isEmpty,
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.soup_kitchen_rounded, size: 16, color: AppColors.success),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Batch #1 (Pesanan Awal)',
                                          style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${savedCartItems.length} menu sudah dikirim ke dapur',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    children: savedCartItems.map((item) {
                                      final savedSubtotal = item.product.harga * item.initialSavedQty;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.product.nama,
                                                    style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${item.initialSavedQty}x @ ${CurrencyFormatter.format(item.product.harga)} (Tersimpan)',
                                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 70,
                                              child: Text(
                                                CurrencyFormatter.format(savedSubtotal),
                                                textAlign: TextAlign.right,
                                                style: AppTypography.titleMedium.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpacing.s),

        if (orderState.isOnlineFood) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monetization_on_rounded, size: 16, color: Colors.orange.shade900),
                    const SizedBox(width: 6),
                    Text(
                      'Input Total di Aplikasi ${orderState.onlinePlatform ?? 'Online'}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _appTotalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Nominal total di aplikasi (Rp)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final cleanText = val.replaceAll('.', '').replaceAll(',', '');
                    final parsed = double.tryParse(cleanText);
                    if (parsed != null) {
                      final formatted = CurrencyFormatter.formatNumber(parsed);
                      if (_appTotalController.text != formatted) {
                        _appTotalController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    } else if (cleanText.isEmpty) {
                      _appTotalController.clear();
                    }
                    orderNotifier.setOnlinePlatformTotal(parsed);
                    setState(() {});
                  },
                ),
                if (orderState.onlinePlatformTotal != null) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final diff = (orderState.onlinePlatformTotal! - cartState.grandTotal).abs();
                      return Text(
                        'Selisih Komisi: ${CurrencyFormatter.format(diff)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],

        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text(CurrencyFormatter.format(cartState.subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const Divider(height: 12),
              Builder(
                builder: (context) {
                  final double? onlineTotal = (orderState.isOnlineFood && orderState.onlinePlatformTotal != null && orderState.onlinePlatformTotal! > 0)
                      ? orderState.onlinePlatformTotal
                      : null;
                  final double effectiveGrandTotal = onlineTotal ?? cartState.grandTotal;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        onlineTotal != null ? 'Grand Total (${orderState.onlinePlatform ?? "Online"})' : 'Grand Total',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        CurrencyFormatter.format(effectiveGrandTotal),
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Simpan',
                type: AppButtonType.secondary,
                isLoading: _isSaving,
                onPressed: cartState.items.isEmpty ? null : _handleSaveDraft,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                text: 'Cetak Bill',
                type: AppButtonType.secondary,
                onPressed: cartState.items.isEmpty ? null : _handlePrintBill,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                text: 'Bayar',
                type: AppButtonType.primary,
                onPressed: cartState.items.isEmpty ? null : _handleGoToPayment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: unprintedCount > 0
                      ? 'Batch Pesanan (+$unprintedCount Baru)'
                      : 'Batch Pesanan',
                  type: unprintedCount > 0 ? AppButtonType.primary : AppButtonType.outlined,
                  icon: Icons.soup_kitchen_rounded,
                  onPressed: _showPrintBatchesDialog,
                ),
              ),
              if (unprintedCount > 0)
                Positioned(
                  top: -6,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '+$unprintedCount Baru',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
