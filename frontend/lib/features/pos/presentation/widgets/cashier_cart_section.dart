import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/di/providers.dart';

import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../screens/payment_screen.dart';
import '../../../table/application/table_notifier.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../../printer/domain/models/printer_config.dart';
import '../../../security/presentation/providers/security_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/utils/receipt_generator.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/models/cart_item.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../product/application/product_notifier.dart';
import '../screens/order_hub_screen.dart';

class CashierCartSection extends ConsumerStatefulWidget {
  final VoidCallback onSaveDraftCompleted;

  const CashierCartSection({super.key, required this.onSaveDraftCompleted});

  @override
  ConsumerState<CashierCartSection> createState() => _CashierCartSectionState();
}

class _CashierCartSectionState extends ConsumerState<CashierCartSection> {
  final TextEditingController noteController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  bool _isSaving = false;
  bool _isOpeningBatch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingName = ref.read(orderNotifierProvider).customerName;
      if (existingName != null) {
        _customerNameController.text = existingName;
      }
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  void _showUnlockDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Otorisasi Manager (Buka Bill)',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bill sudah tercetak. Masukkan PIN Owner/Manager untuk membuka kunci pesanan ini.',
            ),
            SizedBox(height: 16),
            TextField(enableSuggestions: false, autocorrect: false, 
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'PIN (6 Digit)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_rounded),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length != 6) {
                AppSnackbar.showWarning(context, 'Harap isi PIN (6 digit).');
                return;
              }

              const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
              var bytes = utf8.encode(pin + salt);
              var digest = sha256.convert(bytes);
              final hashedPin = digest.toString();

              final isMasterPinValid = await ref
                  .read(securityRepositoryProvider)
                  .validateMasterPin(pin);
              final cashierRepo = ref.read(cashierRepositoryProvider);
              final cashier = await cashierRepo.getCashierByPin(hashedPin);
              final isOwnerCashier = cashier != null && cashier.isOwner == 1;

              if (!context.mounted) return;

              if (!isMasterPinValid && !isOwnerCashier) {
                AppSnackbar.showError(
                  context,
                  'Otorisasi gagal! PIN salah atau bukan Owner.',
                );
                return;
              }

              Navigator.pop(context);
              final activeOrderId = ref
                  .read(orderNotifierProvider)
                  .activeOrder
                  ?.id;
              if (activeOrderId != null) {
                await ref
                    .read(orderNotifierProvider.notifier)
                    .unlockOrder(activeOrderId);
                if (context.mounted) {
                  AppSnackbar.showSuccess(
                    context,
                    'Kunci pesanan berhasil dibuka.',
                  );
                }
              }
            },
            child: Text('Buka Kunci'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoteDialog(BuildContext context, CartItem item) async {
    final noteController = TextEditingController(text: item.catatan);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Catatan Item'),
          content: TextField(enableSuggestions: false, autocorrect: false, 
            controller: noteController,
            decoration: const InputDecoration(
              hintText: 'Masukkan catatan (opsional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(cartNotifierProvider.notifier)
                    .updateCatatan(item.product.id, noteController.text, batchId: item.batchId);
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSaveDraft() async {
    final cartState = ref.read(cartNotifierProvider);
    if (cartState.items.isEmpty) {
      AppSnackbar.showWarning(context, 'Keranjang masih kosong!');
      return;
    }

    // Mencegah IME freeze: Pastikan keyboard tertutup sepenuhnya sebelum dialog muncul
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final printChoice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: AppLoading(message: 'Menyimpan pesanan...'),
                    )
                  : Column(
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
                              child: Icon(
                                Icons.soup_kitchen_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Simpan Pesanan',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Apakah Anda ingin mengirim / mencetak nota pesanan ini ke dapur?',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 20),
                        AppButton(
                          text: 'Ya, Kirim Dapur',
                          icon: Icons.print_rounded,
                          onPressed: () => Navigator.pop(dialogCtx, true),
                        ),
                        SizedBox(height: 10),
                        AppButton(
                          type: AppButtonType.outlined,
                          text: 'Tidak, Hanya Simpan',
                          onPressed: () => Navigator.pop(dialogCtx, false),
                        ),
                        SizedBox(height: 10),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, null),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );

    if (printChoice == null) return;
    await _handleSaveDraftWithKitchenPrint(printChoice);
  }

  Future<void> _handleSaveDraftWithKitchenPrint(
    bool printChoice, {
    bool stayOnScreen = false,
  }) async {
    final cartState = ref.read(cartNotifierProvider);
    final activeUser = ref.read(authSessionProvider);
    if (cartState.items.isEmpty) {
      AppSnackbar.showWarning(context, 'Keranjang masih kosong!');
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(
      const Duration(milliseconds: 100),
    ); // Allow UI to render loading state
    try {
      final orderNotifier = ref.read(orderNotifierProvider.notifier);

      final result = await orderNotifier.saveCurrentOrderDraft(
        cartState.items,
        cartState.subtotal,
        cartState.taxRate,
        cartState.taxAmount,
        cartState.grandTotal,
        cashierId: activeUser?.id,
        cashierNama: activeUser?.nama,
        printToKitchen: printChoice,
      );

      if (!mounted) return;

      if (result != null) {
        AppSnackbar.showSuccess(
          context,
          printChoice
              ? 'Pesanan disimpan & dikirim ke dapur!'
              : 'Pesanan berhasil disimpan!',
        );

        if (stayOnScreen) {
          final orderNotifier = ref.read(orderNotifierProvider.notifier);
          final cartNotifier = ref.read(cartNotifierProvider.notifier);
          final productState = ref.read(productNotifierProvider);

          final activeOrder = ref.read(orderNotifierProvider).activeOrder;
          if (activeOrder != null) {
            if (activeOrder.tableId != null &&
                activeOrder.tableId!.isNotEmpty &&
                activeOrder.tableId != 'TABLE_TAKE_AWAY') {
              await orderNotifier.loadActiveOrderForTable(activeOrder.tableId!);
            } else {
              await orderNotifier.loadOrderById(activeOrder.id);
            }
            final updatedOrderState = ref.read(orderNotifierProvider);
            if (updatedOrderState.activeOrder != null) {
              cartNotifier.loadDraftItems(
                updatedOrderState.activeOrderItems,
                productState.allProducts,
                updatedOrderState.activePrintBatches,
              );
            }
          }
        } else {
          ref.read(orderNotifierProvider.notifier).resetOrder();
          ref.read(cartNotifierProvider.notifier).clear();
          widget.onSaveDraftCompleted();
        }
      } else {
        final err = ref.read(orderNotifierProvider).errorMessage;
        AppSnackbar.showError(
          context,
          err ??
              'Gagal menyimpan pesanan. Pastikan meja atau tipe pesanan telah dipilih.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal menyimpan pesanan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleOpenBatch() async {
    setState(() => _isOpeningBatch = true);
    await Future.delayed(const Duration(milliseconds: 50));

    if (mounted) {
      _showPrintBatchesDialog(); // Don't await, let it return immediately to stop loading
      setState(() => _isOpeningBatch = false);
    }
  }

  Future<void> _showPrintBatchesDialog() async {
    final cartState = ref.read(cartNotifierProvider);
    final orderState = ref.read(orderNotifierProvider);
    final order = orderState.activeOrder;

    int unprintedCount = 0;
    for (var item in cartState.items) {
      if (item.qty > item.initialSavedQty) {
        unprintedCount += (item.qty - item.initialSavedQty).toInt();
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

                        // 1. If unprinted items exist, show prominent action tile at top!
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
                                  await _handleSaveDraftWithKitchenPrint(
                                    true,
                                    stayOnScreen: true,
                                  );
                                }
                                if (mounted) Navigator.pop(dialogCtx);
                              },
                            ),
                          ),
                          SizedBox(height: 14),
                        ],

                        // 2. Existing Printed Batches
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
                                  if (mounted && order != null) {
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
                                if (mounted && order != null) {
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
                        AppButton(
                          type: AppButtonType.outlined,
                          text: 'Tutup',
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
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

      if (!mounted) return;

      if (kitchenPrinters.isEmpty) {
        AppSnackbar.showWarning(context, 'Printer dapur belum dikonfigurasi.');
        return;
      }

      final targetPrinter = kitchenPrinters.first;
      if (!targetPrinter.isConnected) {
        AppSnackbar.showWarning(
          context,
          'Printer dapur (${targetPrinter.name}) sedang tidak terhubung.',
        );
        return;
      }

      final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
        order: order,
        itemsToPrint: itemsToPrint,
        waveInfo: waveInfo,
        paperSize: targetPrinter.escPosPaperSize,
        charsPerLine: targetPrinter.effectiveCharsPerLine,
        autoCut: targetPrinter.autoCut,
      );

      if (!mounted) return;

      final success = await ref
          .read(printerNotifierProvider.notifier)
          .printBytes(targetPrinter, receiptBytes);
      if (mounted) {
        if (success) {
          AppSnackbar.showSuccess(
            context,
            'Struk Dapur $waveInfo berhasil dicetak.',
          );
        } else {
          AppSnackbar.showError(
            context,
            'Gagal mencetak ke printer dapur (${targetPrinter.name}).',
          );
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OrderHubScreen()),
          (route) => route.isFirst,
        );
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

    int unprintedCount = 0;
    for (var item in cartState.items) {
      if (item.qty > item.initialSavedQty) {
        unprintedCount += (item.qty - item.initialSavedQty).toInt();
      }
    }

    final isBilled = orderState.activeOrder?.isBilled ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                orderState.isTakeAway
                    ? Icons.shopping_bag_rounded
                    : Icons.table_restaurant_rounded,
                color: AppColors.primary,
                size: 14,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  orderState.isTakeAway
                      ? (orderState.takeAwaySubType == 'online_food'
                            ? 'Take Away (${orderState.onlinePlatform ?? 'Online Food'})'
                            : 'Take Away (Reguler)')
                      : (orderState.selectedTable?.nama ??
                            orderState.activeOrder?.tableNama ??
                            'Pesanan Meja'),
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        TextField(enableSuggestions: false, autocorrect: false, 
          controller: _customerNameController,
          decoration: InputDecoration(
            hintText: 'Nama Pembeli (Opsional)',
            prefixIcon: const Icon(Icons.person_outline, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (val) {
            ref.read(orderNotifierProvider.notifier).setCustomerName(val);
          },
          style: TextStyle(fontSize: 12.sp),
        ),
        SizedBox(height: 2),

        Expanded(
          child: cartState.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Keranjang Masih Kosong',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (isBilled)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              color: Colors.orange.shade800,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pesanan Terkunci (Bill Sudah Dicetak)',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _showUnlockDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: Colors.orange.shade100,
                              ),
                              child: Text(
                                'Buka',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: orderState.activeOrder != null
                            ? ref
                                  .read(orderRepositoryProvider)
                                  .getPrintBatches(orderState.activeOrder!.id)
                            : Future.value([]),
                        builder: (context, snapshot) {
                          final batches = snapshot.data ?? [];
                          final activeOrderItems = orderState.activeOrderItems
                              .where((i) => !i.isCancelled)
                              .toList();

                          final Map<String, List<OrderItemModel>>
                          batchItemsMap = {};
                          for (var b in batches) {
                            final bId = b['id'] as String;
                            batchItemsMap[bId] = [];
                          }

                          final List<OrderItemModel> unmappedSavedItems = [];
                          for (var item in activeOrderItems) {
                            if (item.printBatchId != null &&
                                batchItemsMap.containsKey(item.printBatchId)) {
                              batchItemsMap[item.printBatchId]!.add(item);
                            } else if (item.statusCetak == 1 ||
                                item.printBatchId != null) {
                              unmappedSavedItems.add(item);
                            }
                          }

                          final newItems = cartState.items
                              .where(
                                (i) =>
                                    i.qty > i.initialSavedQty ||
                                    i.initialSavedQty == 0,
                              )
                              .toList();

                          return ListView(
                            children: [
                              // 1. Batch Baru (Belum Kirim Dapur)
                              if (newItems.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  child: Material(
                                    color: AppColors.primaryContainer
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          initiallyExpanded: true,
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 0,
                                              ),
                                          childrenPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2,
                                              ),
                                          title: Row(
                                            children: [
                                              Icon(
                                                Icons.add_shopping_cart_rounded,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Batch Baru (Belum Kirim)',
                                                style: AppTypography.titleMedium
                                                    .copyWith(
                                                      fontSize: 13.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Text(
                                            '${newItems.length} menu baru',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          children: newItems.map((item) {
                                            final newQty =
                                                item.initialSavedQty > 0
                                                ? item.qty -
                                                      item.initialSavedQty
                                                : item.qty;
                                            final newSubtotal =
                                                item.product.harga * newQty;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 3.0,
                                                    horizontal: 4.0,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              item.product.nama,
                                                              style: AppTypography
                                                                  .titleMedium
                                                                  .copyWith(
                                                                    fontSize:
                                                                        13.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            SizedBox(height: 2),
                                                            Text(
                                                              CurrencyFormatter.format(
                                                                item
                                                                    .product
                                                                    .harga,
                                                              ),
                                                              style: AppTypography
                                                                  .bodySmall
                                                                  .copyWith(
                                                                    color: AppColors
                                                                        .textSecondary,
                                                                  ),
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
                                                          ],
                                                        ),
                                                      ),
                                                      Row(
                                                        children: [
                                                          if (item.canDecrement)
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons
                                                                    .remove_circle_outline_rounded,
                                                                size: 18,
                                                              ),
                                                              color: AppColors
                                                                  .error,
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              constraints:
                                                                  const BoxConstraints(
                                                                    minWidth:
                                                                        28,
                                                                    minHeight:
                                                                        28,
                                                                  ),
                                                              onPressed:
                                                                  item.isBilled
                                                                  ? null
                                                                  : () {
                                                                      cartNotifier.updateQuantity(
                                                                        item
                                                                            .product
                                                                            .id,
                                                                        item.qty -
                                                                            1,
                                                                        batchId: item.batchId,
                                                                      );
                                                                    },
                                                            )
                                                          else
                                                            SizedBox(width: 28),
                                                          Text(
                                                            '$newQty',
                                                            style: AppTypography
                                                                .titleMedium
                                                                .copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      12.sp,
                                                                ),
                                                          ),
                                                          IconButton(
                                                            icon: Icon(
                                                              Icons
                                                                  .add_circle_outline_rounded,
                                                              size: 18,
                                                            ),
                                                            color: item.isBilled
                                                                ? AppColors
                                                                      .disabled
                                                                : AppColors
                                                                      .primary,
                                                            padding:
                                                                EdgeInsets.zero,
                                                            constraints:
                                                                const BoxConstraints(
                                                                  minWidth: 28,
                                                                  minHeight: 28,
                                                                ),
                                                            onPressed:
                                                                item.isBilled
                                                                ? null
                                                                : () {
                                                                    cartNotifier.updateQuantity(
                                                                      item
                                                                          .product
                                                                          .id,
                                                                      item.qty +
                                                                          1,
                                                                      batchId: item.batchId,
                                                                    );
                                                                  },
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(width: 8),
                                                      Flexible(
                                                        flex: 1,
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            CurrencyFormatter.format(
                                                              newSubtotal,
                                                            ),
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: AppTypography
                                                                .titleMedium
                                                                .copyWith(
                                                                  fontSize:
                                                                      12.sp,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (item
                                                      .catatan
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .secondaryContainer,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Catatan: ${item.catatan}',
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .secondaryActive,
                                                          fontSize: 11.sp,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 4),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: TextButton.icon(
                                                      icon: Icon(
                                                        item.catatan.isEmpty
                                                            ? Icons
                                                                  .add_comment_outlined
                                                            : Icons
                                                                  .comment_rounded,
                                                        size: 14,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                      label: Text(
                                                        item.catatan.isEmpty
                                                            ? 'Tambah Catatan'
                                                            : 'Ubah Catatan',
                                                        style: TextStyle(
                                                          color: item.isBilled
                                                              ? AppColors
                                                                    .disabled
                                                              : AppColors
                                                                    .primary,
                                                          fontSize: 11.sp,
                                                        ),
                                                      ),
                                                      onPressed: item.isBilled
                                                          ? null
                                                          : () =>
                                                                _showNoteDialog(
                                                                  context,
                                                                  item,
                                                                ),
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        minimumSize: const Size(
                                                          60,
                                                          32,
                                                        ),
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
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
                                      if (i == 0 &&
                                          unmappedSavedItems.isNotEmpty) {
                                        bItems = [
                                          ...bItems,
                                          ...unmappedSavedItems,
                                        ];
                                      }
                                      if (bItems.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      final bNum = i + 1;
                                      final bTitle = bNum == 1
                                          ? 'Batch #1 (Pesanan Awal)'
                                          : 'Batch #$bNum (Pesanan Tambahan)';
                                      final bSubtotal = bItems.fold<double>(
                                        0,
                                        (sum, item) => sum + item.subtotal,
                                      );

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Material(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Theme(
                                              data: Theme.of(context).copyWith(
                                                dividerColor:
                                                    Colors.transparent,
                                              ),
                                              child: ExpansionTile(
                                                initiallyExpanded:
                                                    newItems.isEmpty &&
                                                    i == batches.length - 1,
                                                tilePadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 0,
                                                    ),
                                                childrenPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 2,
                                                    ),
                                                title: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .soup_kitchen_rounded,
                                                      size: 16,
                                                      color: AppColors.success,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      bTitle,
                                                      style: AppTypography
                                                          .titleMedium
                                                          .copyWith(
                                                            fontSize: 13.sp,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: AppColors
                                                                .success,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                subtitle: Text(
                                                  '${bItems.length} menu • ${CurrencyFormatter.format(bSubtotal)}',
                                                  style: TextStyle(
                                                    fontSize: 11.sp,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                children: bItems.map((item) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 3.0,
                                                          horizontal: 4.0,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                item.produkNama,
                                                                style: AppTypography
                                                                    .titleMedium
                                                                    .copyWith(
                                                                      fontSize:
                                                                          13.sp,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                '${item.qty}x @ ${CurrencyFormatter.format(item.produkHarga)} (Tersimpan)',
                                                                style: AppTypography
                                                                    .bodySmall
                                                                    .copyWith(
                                                                      color: AppColors
                                                                          .textSecondary,
                                                                      fontSize:
                                                                          11.sp,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Flexible(
                                                          flex: 1,
                                                          child: FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: Text(
                                                              CurrencyFormatter.format(
                                                                item.subtotal,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                              style: AppTypography
                                                                  .titleMedium
                                                                  .copyWith(
                                                                    fontSize:
                                                                        12.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: AppColors
                                                                        .textSecondary,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ] else if (cartState.items.any(
                                (i) => i.initialSavedQty > 0,
                              )) ...[
                                // Fallback if no batch record exists in database table
                                Builder(
                                  builder: (context) {
                                    final savedCartItems = cartState.items
                                        .where((i) => i.initialSavedQty > 0)
                                        .toList();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      child: Material(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Theme(
                                            data: Theme.of(context).copyWith(
                                              dividerColor: Colors.transparent,
                                            ),
                                            child: ExpansionTile(
                                              initiallyExpanded:
                                                  newItems.isEmpty,
                                              tilePadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 0,
                                                  ),
                                              childrenPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              title: Row(
                                                children: [
                                                  Icon(
                                                    Icons.soup_kitchen_rounded,
                                                    size: 16,
                                                    color: AppColors.success,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Batch #1 (Pesanan Awal)',
                                                    style: AppTypography
                                                        .titleMedium
                                                        .copyWith(
                                                          fontSize: 13.sp,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors.success,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              subtitle: Text(
                                                '${savedCartItems.length} menu sudah dikirim ke dapur',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              children: savedCartItems.map((
                                                item,
                                              ) {
                                                final savedSubtotal =
                                                    item.product.harga *
                                                    item.initialSavedQty;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 3.0,
                                                        horizontal: 4.0,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 3,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              item.product.nama,
                                                              style: AppTypography
                                                                  .titleMedium
                                                                  .copyWith(
                                                                    fontSize:
                                                                        13.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            SizedBox(height: 2),
                                                            Text(
                                                              '${item.initialSavedQty}x @ ${CurrencyFormatter.format(item.product.harga)} (Tersimpan)',
                                                              style: AppTypography
                                                                  .bodySmall
                                                                  .copyWith(
                                                                    color: AppColors
                                                                        .textSecondary,
                                                                    fontSize:
                                                                        11.sp,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Flexible(
                                                        flex: 1,
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            CurrencyFormatter.format(
                                                              savedSubtotal,
                                                            ),
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: AppTypography
                                                                .titleMedium
                                                                .copyWith(
                                                                  fontSize:
                                                                      12.sp,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: AppColors
                                                                      .textSecondary,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
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
                  ],
                ),
        ),
        SizedBox(height: AppSpacing.xs),

        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(cartState.subtotal),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Divider(height: 8),
              Builder(
                builder: (context) {
                  final double? onlineTotal =
                      (orderState.isOnlineFood &&
                          orderState.onlinePlatformTotal != null &&
                          orderState.onlinePlatformTotal! > 0)
                      ? orderState.onlinePlatformTotal
                      : null;
                  final double effectiveGrandTotal =
                      onlineTotal ?? cartState.grandTotal;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        onlineTotal != null
                            ? 'Grand Total (${orderState.onlinePlatform ?? "Online"})'
                            : 'Grand Total',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(effectiveGrandTotal),
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 2),

        SizedBox(
          height: 30,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSaving
                  ? AppColors.disabled.withValues(alpha: 0.3)
                  : AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              textStyle: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: cartState.items.isEmpty ? null : _handleSaveDraft,
            child: _isSaving
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Simpan', overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}
