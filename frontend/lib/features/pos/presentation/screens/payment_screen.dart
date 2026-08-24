import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../product/presentation/widgets/product_form.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/di/providers.dart';
import '../../../payment_method/application/payment_method_notifier.dart';
import '../../../payment_method/domain/models/payment_method.dart';
import '../../application/cart_notifier.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../core/utils/pdf_receipt_generator.dart';
import '../../../../core/widgets/app_receipt_preview_modal.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

import '../../application/order_notifier.dart';
import '../../../table/application/table_notifier.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/print_batch.dart';
import '../../domain/models/order_item.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();
  final _appTotalController = TextEditingController();
  final _uuid = const Uuid();
  
  PaymentMethod? _selectedMethod;
  bool _isProcessing = false;
  String _orderNumber = '';

  @override
  void initState() {
    super.initState();
    // Load active payment methods
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(paymentMethodNotifierProvider.notifier).loadPaymentMethods();
      final methods = ref.read(paymentMethodNotifierProvider).allMethods.where((p) => p.isActive).toList();
      if (methods.isNotEmpty) {
        setState(() {
          _selectedMethod = methods.firstWhere(
            (p) => p.id == 'pm-tunai',
            orElse: () => methods.first,
          );
        });
      }
      
      // Generate next order number
      final orderNo = await ref.read(transactionRepositoryProvider).generateNextOrderNumber();
      setState(() => _orderNumber = orderNo);

      final orderState = ref.read(orderNotifierProvider);
      final total = orderState.onlinePlatformTotal ?? orderState.activeOrder?.onlinePlatformTotal;
      if (total != null && total > 0) {
        _appTotalController.text = CurrencyFormatter.formatNumber(total);
        if (orderState.onlinePlatformTotal == null) {
          ref.read(orderNotifierProvider.notifier).setOnlinePlatformTotal(total);
        }
      }
    });
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _notesController.dispose();
    _appTotalController.dispose();
    super.dispose();
  }

  // Preset buttons for cash payment
  void _applyPresetAmount(double amount) {
    setState(() {
      _amountPaidController.text = CurrencyFormatter.formatNumber(amount);
    });
  }

  void _showNonCashMethodsSheet(List<PaymentMethod> activeMethods) {
    final nonCashMethods = activeMethods.where((m) => m.id != 'pm-tunai').toList();
    if (nonCashMethods.isEmpty) {
      AppSnackbar.showWarning(context, 'Tidak ada metode pembayaran non-tunai aktif.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Metode Non-Tunai',
                      style: AppTypography.titleMedium.copyWith(fontSize: 18.sp),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: nonCashMethods.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, idx) {
                      final method = nonCashMethods[idx];
                      final isSelected = _selectedMethod?.id == method.id;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryContainer : AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            method.iconData,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          method.nama,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedMethod = method;
                            _amountPaidController.clear();
                          });
                          Navigator.pop(context);
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

  Future<void> _handlePayment(
    double grandTotal,
    double subtotal,
    double taxRate,
    double taxAmount, {
    required bool isPayLater,
  }) async {
    final cartState = ref.read(cartNotifierProvider);
    if (cartState.items.isEmpty) {
      AppSnackbar.showWarning(context, 'Keranjang pesanan kosong.');
      return;
    }

    final orderState = ref.read(orderNotifierProvider);
    final activeOrder = orderState.activeOrder;
    if (activeOrder != null) {
      final freshOrder = await ref.read(orderRepositoryProvider).getOrderById(activeOrder.id);
      if (freshOrder != null && freshOrder.isCompleted) {
        AppSnackbar.showWarning(context, 'Pesanan ini sudah selesai / dibayar sebelumnya.');
        return;
      }
    }

    double amountPaid = 0;
    double change = 0;

    if (!isPayLater) {
      if (_selectedMethod == null) {
        AppSnackbar.showWarning(context, 'Pilih metode pembayaran terlebih dahulu.');
        return;
      }
      final isCash = _selectedMethod!.id == 'pm-tunai';
      amountPaid = grandTotal;
      if (isCash) {
        if (_amountPaidController.text.isEmpty) {
          AppSnackbar.showWarning(context, 'Masukkan nominal pembayaran tunai.');
          return;
        }
        amountPaid = double.tryParse(_amountPaidController.text.replaceAll('.', '')) ?? 0;
        if (amountPaid < grandTotal) {
          AppSnackbar.showWarning(context, 'Jumlah bayar kurang dari total transaksi.');
          return;
        }
      }
      change = amountPaid - grandTotal;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 100)); // Allow UI to render loading state

    try {
      final activeUser = ref.read(authSessionProvider);
      final orderState = ref.read(orderNotifierProvider);
      final notes = _notesController.text.trim();

      // 1. Simpan draft pesanan (upsert pesanan & order_items, print struk dapur, dan set status meja = 1 Terisi/Billed)
      await ref.read(orderNotifierProvider.notifier).saveCurrentOrderDraft(
            cartState.items,
            subtotal,
            taxRate,
            taxAmount,
            grandTotal,
            notes: notes.isNotEmpty ? notes : null,
            cashierId: activeUser?.id,
            cashierNama: activeUser?.nama,
          );
      // Refresh list meja agar status meja terbaru (1 = Terisi / Billed) termuat
      ref.read(tableNotifierProvider.notifier).loadTables();

      TransactionHeader? savedHeader;
      List<TransactionItem>? savedItems;

      // 2. Jika Bayar Sekarang (lunas di awal), catat transaksi ke database transactions
      if (!isPayLater && _selectedMethod != null) {
        final txId = _uuid.v4();
        final double storeTotal = subtotal + taxAmount;
        final double? platformTotal = orderState.onlinePlatformTotal ?? orderState.activeOrder?.onlinePlatformTotal;
        final double? platformDiff = platformTotal != null ? (platformTotal - storeTotal) : null;

        savedHeader = TransactionHeader(
          id: txId,
          nomorTransaksi: _orderNumber,
          subtotal: subtotal,
          taxPercentage: taxRate,
          taxAmount: taxAmount,
          grandTotal: grandTotal,
          onlinePlatformTotal: platformTotal,
          platformDifference: platformDiff,
          onlinePlatform: orderState.onlinePlatform ?? orderState.activeOrder?.onlinePlatform,
          paymentMethodId: _selectedMethod!.id,
          paymentMethodNama: _selectedMethod!.nama,
          nominalBayar: amountPaid,
          kembalian: change,
          catatan: notes,
          customerName: orderState.customerName,
          orderType: orderState.orderType,
          createdAt: DateTime.now(),
          cashierId: activeUser?.id,
          cashierNama: activeUser?.nama,
        );

        final List<TransactionItem> consolidatedTxItems = [];
        final Map<String, int> regularIndexMap = {};

        for (var item in cartState.items) {
          if (item.product.isPackage) {
            // Packages are kept separate per batch
            consolidatedTxItems.add(TransactionItem(
              id: _uuid.v4(),
              transactionId: txId,
              produkId: item.product.id,
              produkNama: item.product.nama,
              produkHarga: item.product.harga,
              qty: item.qty,
              subtotal: item.subtotal,
              catatan: item.catatan.isNotEmpty ? item.catatan : null,
            ));
          } else {
            final key = '${item.product.id}_${item.product.harga}';
            if (regularIndexMap.containsKey(key)) {
              final idx = regularIndexMap[key]!;
              final existing = consolidatedTxItems[idx];
              String? mergedNotes = existing.catatan;
              if (item.catatan.isNotEmpty) {
                if (mergedNotes == null || mergedNotes.isEmpty) {
                  mergedNotes = item.catatan;
                } else if (!mergedNotes.contains(item.catatan)) {
                  mergedNotes = '$mergedNotes, ${item.catatan}';
                }
              }
              consolidatedTxItems[idx] = TransactionItem(
                id: existing.id,
                transactionId: txId,
                produkId: existing.produkId,
                produkNama: existing.produkNama,
                produkHarga: existing.produkHarga,
                qty: existing.qty + item.qty,
                subtotal: existing.subtotal + item.subtotal,
                catatan: mergedNotes,
              );
            } else {
              regularIndexMap[key] = consolidatedTxItems.length;
              consolidatedTxItems.add(TransactionItem(
                id: _uuid.v4(),
                transactionId: txId,
                produkId: item.product.id,
                produkNama: item.product.nama,
                produkHarga: item.product.harga,
                qty: item.qty,
                subtotal: item.subtotal,
                catatan: item.catatan.isNotEmpty ? item.catatan : null,
              ));
            }
          }
        }

        savedItems = consolidatedTxItems;
        await ref.read(transactionRepositoryProvider).saveTransaction(savedHeader, savedItems);

        // Jika transaksi dari order aktif, tandai order 'paid' dan bebaskan meja jika sudah lunas semua
        final currentOrderState = ref.read(orderNotifierProvider);
        final activeOrder = currentOrderState.activeOrder;
        if (activeOrder != null) {
          // Full payment
          await ref.read(orderRepositoryProvider).updatePaymentStatus(activeOrder.id, 'paid');
          await ref.read(orderRepositoryProvider).completeOrder(activeOrder.id, tableId: activeOrder.tableId);
          
          // Mark all batches as paid since we're paying the full order
          final allBatches = await ref.read(orderRepositoryProvider).getPrintBatches(activeOrder.id);
          for (var b in allBatches) {
            await ref.read(orderRepositoryProvider).updatePrintBatchPaymentStatus(b['id'], 'paid');
          }
        }

        // Refresh list meja & active orders map
        ref.read(tableNotifierProvider.notifier).loadTables();
        await ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();

        // Buka laci kasir (Cash Drawer Kick) saat tombol bayar ditekan
        try {
          ref.read(printerNotifierProvider.notifier).openCashDrawer();
        } catch (_) {}

        // Opsi otomatis cetak ke thermal kasir jika terhubung
        try {
          final printerState = ref.read(printerNotifierProvider);
          final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
          final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

          if (cashierPrinter != null) {
            if (cashierPrinter.isConnected) {
              final receiptBytes = await ReceiptGenerator.generateCashierReceipt(
                transaction: savedHeader,
                items: savedItems,
                tableName: orderState.selectedTable?.nama,
                paperSize: cashierPrinter.escPosPaperSize ?? PaperSize.mm58,
                charsPerLine: cashierPrinter.effectiveCharsPerLine ?? 32,
                autoCut: cashierPrinter.autoCut ?? false,
              );

              // Fire and forget so we don't freeze the payment flow
              ref.read(printerNotifierProvider.notifier).printBytes(cashierPrinter, receiptBytes).then((success) {
                if (!success && mounted) {
                  AppSnackbar.showWarning(context, 'Cetak otomatis dilewati: Printer kasir tidak merespons.');
                }
              });
            } else {
              AppSnackbar.showWarning(context, 'Cetak otomatis dilewati: Printer kasir belum terhubung.');
            }
          }
        } catch (_) {}
      }

      setState(() => _isProcessing = false);
      if (!mounted) return;

      // 3. Tampilkan pop-up "Cetak Pesanan"
      _showPrintOrderPopup(
        isPaid: !isPayLater,
        header: savedHeader,
        txItems: savedItems,
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString());
    }
  }

  void _showPrintOrderPopup({
    required bool isPaid,
    TransactionHeader? header,
    List<TransactionItem>? txItems,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final orderState = ref.read(orderNotifierProvider);
        final order = orderState.activeOrder;
        final orderItems = orderState.activeOrderItems;
        final tableName = orderState.selectedTable?.nama ?? 'Take Away';

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 48,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    isPaid ? 'Pembayaran Berhasil!' : 'Pesanan Berhasil Disimpan!',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 18.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    isPaid
                        ? (tableName == 'Take Away' ? 'Transaksi Lunas.' : 'Transaksi Lunas. Meja $tableName kini kembali Kosong.')
                        : 'Open Bill tersimpan. Meja $tableName berstatus Terisi / Billed.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 20),
                  const Divider(),
                  SizedBox(height: 12),
                  Text(
                    'Pilihan Cetak Pesanan',
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  if (isPaid && header != null && txItems != null) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final printerState = ref.read(printerNotifierProvider);
                        final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
                        final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

                        final textPreview = await ReceiptGenerator.formatCashierTextPreview(
                          transaction: header,
                          items: txItems,
                          tableName: orderState.selectedTable?.nama,
                          charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
                        );

                        if (!mounted) return;
                        AppReceiptPreviewModal.show(
                          context,
                          title: 'STRUK LUNAS',
                          receiptTextPreview: textPreview,
                          printerType: 'cashier',
                          onGeneratePdf: () => PdfReceiptGenerator.generateCashierReceiptPdf(
                            transaction: header,
                            items: txItems,
                            tableName: orderState.selectedTable?.nama,
                          ),
                          onGenerateEscPosBytes: () => ReceiptGenerator.generateCashierReceipt(
                            transaction: header,
                            items: txItems,
                            tableName: orderState.selectedTable?.nama,
                            paperSize: cashierPrinter?.escPosPaperSize ?? PaperSize.mm58,
                            charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
                            autoCut: cashierPrinter?.autoCut ?? false,
                          ),
                        );
                      },
                      icon: Icon(Icons.receipt_long_rounded, color: AppColors.success),
                      label: Text('Cetak Nota (Lunas)', style: TextStyle(color: AppColors.success)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.success),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ] else if (order != null) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final activeUser = ref.read(authSessionProvider);
                        final printerState = ref.read(printerNotifierProvider);
                        final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
                        final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

                        final textPreview = await ReceiptGenerator.formatBillTextPreview(
                          order: order,
                          items: orderItems,
                          cashierNama: order.cashierNama ?? activeUser?.nama,
                          charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
                        );

                        if (!mounted) return;
                        AppReceiptPreviewModal.show(
                          context,
                          title: 'BILL SEMENTARA',
                          receiptTextPreview: textPreview,
                          printerType: 'cashier',
                          onGeneratePdf: () => PdfReceiptGenerator.generateBillPdf(
                            order: order,
                            items: orderItems,
                            cashierNama: order.cashierNama ?? activeUser?.nama,
                          ),
                          onGenerateEscPosBytes: () => ReceiptGenerator.generateBillReceipt(
                            order: order,
                            items: orderItems,
                            cashierNama: order.cashierNama ?? activeUser?.nama,
                            paperSize: cashierPrinter?.escPosPaperSize ?? PaperSize.mm58,
                            charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
                            autoCut: cashierPrinter?.autoCut ?? false,
                          ),
                        );
                      },
                      icon: Icon(Icons.receipt_long_rounded, color: AppColors.secondary),
                      label: Text('Cetak Bill Sementara', style: TextStyle(color: AppColors.secondary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.secondary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext); // close dialog
                      _finishAndResetTransaction();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Selesai & Kembali ke POS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _finishAndResetTransaction() {
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final tableNotifier = ref.read(tableNotifierProvider.notifier);

    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.popUntil(context, (route) => route.settings.name == '/order_hub' || route.isFirst);
    }

    // Beri jeda waktu agar animasi pop screen selesai sebelum mereset state,
    // mencegah freeze akibat re-build masif pada screen yang sedang dianimasikan keluar.
    Future.delayed(const Duration(milliseconds: 300), () {
      cartNotifier.clear();
      orderNotifier.resetOrder();
      tableNotifier.loadTables();
      orderNotifier.loadActiveOrdersMap();
    });
  }



  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartNotifierProvider);
    final orderState = ref.watch(orderNotifierProvider);
    final pmState = ref.watch(paymentMethodNotifierProvider);
    final activeMethods = pmState.allMethods.where((p) => p.isActive).toList();

    final isCash = _selectedMethod?.id == 'pm-tunai';
    final storeSubtotal = cartState.subtotal;
    final storeTaxAmount = cartState.taxAmount;
    final storeGrandTotal = cartState.grandTotal;

    final double? onlineTotal = (orderState.isOnlineFood && orderState.onlinePlatformTotal != null && orderState.onlinePlatformTotal! > 0)
        ? orderState.onlinePlatformTotal
        : null;

    final grandTotal = storeGrandTotal;

    double amountPaid = 0;
    if (isCash) {
      amountPaid = double.tryParse(_amountPaidController.text.replaceAll('.', '')) ?? 0;
    } else {
      amountPaid = grandTotal;
    }
    final change = amountPaid - grandTotal;
    final isPayDisabled = isCash && amountPaid < grandTotal;

    return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          toolbarHeight: ResponsiveLayout.isMobileLandscape(context) ? 42 : null,
          title: Text('Pembayaran Transaksi', style: TextStyle(fontSize: ResponsiveLayout.isMobileLandscape(context) ? 14 : 16)),
          leading: IconButton(
            icon: Icon(Icons.close_rounded),
            tooltip: 'Batal',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final isMobileLandscape = ResponsiveLayout.isMobileLandscape(context);
                  final paddingVal = isMobileLandscape ? AppSpacing.s : AppSpacing.l;
                  
                  final billingPanel = _buildBillingPanel(
                    cartState, pmState, activeMethods, isCash, grandTotal,
                    storeSubtotal, storeTaxAmount,
                    onlineTotal: onlineTotal,
                    onlinePlatform: orderState.onlinePlatform,
                  );
                  final paymentPanel = _buildPaymentPanel(
                    isCash, grandTotal, change, isPayDisabled, cartState,
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isMobileLandscape ? 1 : 3,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(paddingVal),
                            child: billingPanel,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: isMobileLandscape ? 1 : 2,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(paddingVal),
                            child: paymentPanel,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(paddingVal),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          billingPanel,
                          const Divider(height: 32),
                          paymentPanel,
                        ],
                      ),
                    );
                  }
                },
              ),
        ),
      );
  }

  Widget _buildBillingPanel(
    CartState cartState,
    dynamic pmState,
    List<PaymentMethod> activeMethods,
    bool isCash,
    double grandTotal,
    double storeSubtotal,
    double storeTaxAmount, {
    double? onlineTotal,
    String? onlinePlatform,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // Invoice summary header card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            borderSide: const BorderSide(color: AppColors.divider),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('No. Transaksi', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    Text(_orderNumber, style: AppTypography.titleMedium.copyWith(fontSize: 15.sp)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    Text(CurrencyFormatter.format(storeSubtotal), style: AppTypography.bodyMedium),
                  ],
                ),
                if (cartState.taxRate > 0) ...[
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pajak (PPN ${cartState.taxRate.toStringAsFixed(0)}%)',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.format(storeTaxAmount), style: AppTypography.bodyMedium),
                    ],
                  ),
                ],
                if (onlineTotal != null) ...[
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tagihan Aplikasi (${onlinePlatform ?? "Online"})',
                          style: AppTypography.bodyMedium.copyWith(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                      Text(CurrencyFormatter.format(onlineTotal),
                          style: AppTypography.bodyMedium.copyWith(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Bayar', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyFormatter.format(grandTotal),
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          if (ref.read(orderNotifierProvider).isOnlineFood) ...[
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
                      SizedBox(width: 6),
                      Text(
                        'Input Total di Aplikasi ${onlinePlatform ?? 'Online'}',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  TextField(enableSuggestions: false, autocorrect: false, 
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
                      ref.read(orderNotifierProvider.notifier).setOnlinePlatformTotal(parsed);
                      setState(() {});
                    },
                  ),
                  if (onlineTotal != null) ...[
                    SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final diff = (onlineTotal - cartState.grandTotal).abs();
                        return Text(
                          'Selisih Komisi: ${CurrencyFormatter.format(diff)}',
                          style: TextStyle(
                            fontSize: 11.sp,
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
            SizedBox(height: 24),
          ],
          Text('Metode Pembayaran', style: AppTypography.titleMedium),
          SizedBox(height: 12),
          // Payment methods selection (Tunai vs Non-Tunai)
          pmState.isLoading
              ? Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    // Tunai Option
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isCashSelected = _selectedMethod?.id == 'pm-tunai';
                          return AppCard(
                            onTap: () {
                              final cashMethod = activeMethods.firstWhere(
                                (p) => p.id == 'pm-tunai',
                                orElse: () => activeMethods.first,
                              );
                              setState(() {
                                _selectedMethod = cashMethod;
                              });
                            },
                            color: isCashSelected ? AppColors.primaryContainer : Colors.white,
                            borderSide: BorderSide(
                              color: isCashSelected ? AppColors.primary : AppColors.divider,
                              width: isCashSelected ? 2.0 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.payments_rounded,
                                  color: isCashSelected ? AppColors.primary : AppColors.textSecondary,
                                  size: 28,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tunai (Cash)',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: isCashSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isCashSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ),
                    SizedBox(width: 12),
                    // Non-Tunai Option
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isNonCashSelected = _selectedMethod != null && _selectedMethod!.id != 'pm-tunai';
                          return AppCard(
                            onTap: () => _showNonCashMethodsSheet(activeMethods),
                            color: isNonCashSelected ? AppColors.primaryContainer : Colors.white,
                            borderSide: BorderSide(
                              color: isNonCashSelected ? AppColors.primary : AppColors.divider,
                              width: isNonCashSelected ? 2.0 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isNonCashSelected ? _selectedMethod!.iconData : Icons.credit_card_rounded,
                                  color: isNonCashSelected ? AppColors.primary : AppColors.textSecondary,
                                  size: 28,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  isNonCashSelected ? _selectedMethod!.nama : 'Non-Tunai',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: isNonCashSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isNonCashSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
          SizedBox(height: 24),
          AppTextField(
            controller: _notesController,
            labelText: 'Catatan Transaksi',
            hintText: 'Contoh: No. referensi transfer bank, dll.',
            prefixIcon: Icons.notes_outlined,
          ),
        ],
      );
  }

  Widget _buildPaymentPanel(
    bool isCash,
    double grandTotal,
    double change,
    bool isPayDisabled,
    CartState cartState,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCash) ...[
            Text('Pembayaran Tunai', style: AppTypography.titleMedium.copyWith(fontSize: 18.sp)),
            SizedBox(height: 20),
            AppTextField(
              controller: _amountPaidController,
              labelText: 'Nominal Uang Diterima',
              prefixText: 'Rp ',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(maxDigits: 10),
              ],
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16),
            // Quick cash buttons
            Text('Pilih Cepat Uang Pas/Pasaran:',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(grandTotal),
                  child: Text('Uang Pas'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(20000),
                  child: Text('20.000'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(50000),
                  child: Text('50.000'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(100000),
                  child: Text('100.000'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(200000),
                  child: Text('200.000'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(500000),
                  child: Text('500.000'),
                ),
              ],
            ),
            const Divider(height: 32),
            // Change (Kembalian) Card
            AppCard(
              color: change >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              borderSide: BorderSide(color: change >= 0 ? Colors.green.shade200 : Colors.red.shade200),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    change >= 0 ? 'Uang Kembalian' : 'Kekurangan Bayar',
                    style: TextStyle(
                      color: change >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(change.abs()),
                    style: TextStyle(
                      color: change >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text('Pembayaran Non-Tunai', style: AppTypography.titleMedium.copyWith(fontSize: 18.sp)),
            SizedBox(height: 16),
            AppCard(
              color: AppColors.primaryContainer.withAlpha(77),
              borderSide: const BorderSide(color: AppColors.primaryContainer),
              child: Text(
                'Transaksi dengan metode pembayaran ${_selectedMethod?.nama ?? ""} dicatat lunas sebesar ${CurrencyFormatter.format(grandTotal)}. Harap pastikan dana telah masuk/diterima secara manual sebelum menyelesaikan transaksi.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: 'Bayar Sekarang',
              type: AppButtonType.primary,
              isLoading: _isProcessing,
              onPressed: isPayDisabled || _isProcessing
                  ? null
                  : () => _handlePayment(
                        grandTotal,
                        cartState.subtotal,
                        cartState.taxRate,
                        cartState.taxAmount,
                        isPayLater: false,
                      ),
              icon: Icons.payments_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
