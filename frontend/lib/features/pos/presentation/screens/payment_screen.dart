import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/di/providers.dart';
import '../../../payment_method/application/payment_method_notifier.dart';
import '../../../payment_method/domain/models/payment_method.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/cart_notifier.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

import '../../application/order_notifier.dart';
import '../../../table/application/table_notifier.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../domain/models/transaction.dart';
import '../../../menu/presentation/screens/main_menu_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();
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
    });
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _notesController.dispose();
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
                      style: AppTypography.titleMedium.copyWith(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
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

  Future<void> _handlePayment(double grandTotal, double subtotal, double taxRate, double taxAmount) async {
    if (_selectedMethod == null) {
      AppSnackbar.showWarning(context, 'Pilih metode pembayaran terlebih dahulu.');
      return;
    }

    final isCash = _selectedMethod!.id == 'pm-tunai';
    double amountPaid = grandTotal;
    
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

    final change = amountPaid - grandTotal;

    setState(() => _isProcessing = true);

    try {
      final txId = _uuid.v4();
      final activeUser = ref.read(authSessionProvider);
      final header = TransactionHeader(

        id: txId,
        nomorTransaksi: _orderNumber,
        subtotal: subtotal,
        taxPercentage: taxRate,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        paymentMethodId: _selectedMethod!.id,
        paymentMethodNama: _selectedMethod!.nama,
        nominalBayar: amountPaid,
        kembalian: change,
        catatan: _notesController.text.trim(),
        createdAt: DateTime.now(),
        cashierId: activeUser?.id,
        cashierNama: activeUser?.nama,
      );


      final cartState = ref.read(cartNotifierProvider);
      final List<TransactionItem> items = cartState.items.map((item) {
        return TransactionItem(
          id: _uuid.v4(),
          transactionId: txId,
          produkId: item.product.id,
          produkNama: item.product.nama,
          produkHarga: item.product.harga,
          qty: item.qty,
          subtotal: item.subtotal,
          catatan: item.catatan,
        );
      }).toList();

      // Save transaction to local SQLite DB and deduct stock
      await ref.read(transactionRepositoryProvider).saveTransaction(header, items);

      final orderState = ref.read(orderNotifierProvider);
      
      // 1. If this transaction is linked to a table order draft, mark it completed (but do not release table status to Empty)
      if (orderState.selectedTable != null && orderState.activeOrder != null) {
        await ref.read(orderRepositoryProvider).completeOrder(
          orderState.activeOrder!.id,
        );
        ref.read(orderNotifierProvider.notifier).clearActiveOrder();
        ref.read(tableNotifierProvider.notifier).loadTables();
      }

      // 2. Format and print Cashier Receipt
      final printerState = ref.read(printerNotifierProvider);
      final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
      final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

      final receiptBytes = await ReceiptGenerator.generateCashierReceipt(
        transaction: header,
        items: items,
        tableName: orderState.selectedTable?.nama,
        paperSize: cashierPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: cashierPrinter?.autoCut ?? false,
      );

      if (cashierPrinter != null) {
        await ref.read(printerNotifierProvider.notifier).printBytes(cashierPrinter, receiptBytes);
      } else {
        if (kDebugMode) {
          debugPrint('--- PRINT TO CASHIER SIMULATOR ---');
          debugPrint(String.fromCharCodes(receiptBytes));
          debugPrint('----------------------------------');
        }
      }

      // Refresh product notifier state to reflect stock changes
      ref.read(productNotifierProvider.notifier).loadProducts();

      // Clear Shopping Cart on success
      ref.read(cartNotifierProvider.notifier).clear();

      setState(() => _isProcessing = false);

      if (!mounted) return;
      _showSuccessDialog(header, items);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString());
    }
  }

  void _showSuccessDialog(TransactionHeader header, List<TransactionItem> items) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialog(
        title: 'Transaksi Sukses',
        confirmText: 'Kembali Ke Transaksi',
        cancelText: 'Menu Utama',
        onCancel: () {
          // Navigate to main menu and clear stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainMenuScreen()),
            (route) => false,
          );
        },
        onConfirm: () {
          // Go back to POS screen
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to POS screen
        },
        content: Column(
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
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Berhasil!',
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(fontSize: 18, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            _buildDialogRow('No. Struk', header.nomorTransaksi),
            _buildDialogRow('Metode Bayar', header.paymentMethodNama),
            _buildDialogRow('Total Belanja', CurrencyFormatter.format(header.grandTotal)),
            _buildDialogRow('Jumlah Bayar', CurrencyFormatter.format(header.nominalBayar)),
            _buildDialogRow('Kembalian', CurrencyFormatter.format(header.kembalian), isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartNotifierProvider);
    final pmState = ref.watch(paymentMethodNotifierProvider);
    final activeMethods = pmState.allMethods.where((p) => p.isActive).toList();

    final isCash = _selectedMethod?.id == 'pm-tunai';
    final grandTotal = cartState.grandTotal;

    double amountPaid = 0;
    if (isCash) {
      amountPaid = double.tryParse(_amountPaidController.text.replaceAll('.', '')) ?? 0;
    } else {
      amountPaid = grandTotal;
    }
    final change = amountPaid - grandTotal;
    final isPayDisabled = isCash && amountPaid < grandTotal;

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
          title: const Text('Pembayaran Transaksi'),
        ),
        body: SafeArea(
          child: _isProcessing
              ? const AppLoading(message: 'Menyimpan transaksi offline...')
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  
                  final billingPanel = _buildBillingPanel(
                    cartState, pmState, activeMethods, isCash, grandTotal,
                  );
                  final paymentPanel = _buildPaymentPanel(
                    isCash, grandTotal, change, isPayDisabled, cartState,
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.l),
                            child: billingPanel,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.l),
                            child: paymentPanel,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.l),
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
    ),
  );
}

  Widget _buildBillingPanel(
    CartState cartState,
    dynamic pmState,
    List<PaymentMethod> activeMethods,
    bool isCash,
    double grandTotal,
  ) {
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
                    Text(_orderNumber, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    Text(CurrencyFormatter.format(cartState.subtotal), style: AppTypography.bodyMedium),
                  ],
                ),
                if (cartState.taxRate > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pajak (PPN ${cartState.taxRate.toStringAsFixed(0)}%)',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.format(cartState.taxAmount), style: AppTypography.bodyMedium),
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
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Metode Pembayaran', style: AppTypography.titleMedium),
          const SizedBox(height: 12),
          // Payment methods selection (Tunai vs Non-Tunai)
          pmState.isLoading
              ? const Center(child: CircularProgressIndicator())
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
                                const SizedBox(height: 8),
                                Text(
                                  'Tunai (Cash)',
                                  style: TextStyle(
                                    fontSize: 14,
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
                    const SizedBox(width: 12),
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
                                const SizedBox(height: 8),
                                Text(
                                  isNonCashSelected ? _selectedMethod!.nama : 'Non-Tunai',
                                  style: TextStyle(
                                    fontSize: 14,
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
          const SizedBox(height: 24),
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
            Text('Pembayaran Tunai', style: AppTypography.titleMedium.copyWith(fontSize: 18)),
            const SizedBox(height: 20),
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
            const SizedBox(height: 16),
            // Quick cash buttons
            Text('Pilih Cepat Uang Pas/Pasaran:',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(grandTotal),
                  child: const Text('Uang Pas'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(20000),
                  child: const Text('20.000'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(50000),
                  child: const Text('50.000'),
                ),
                OutlinedButton(
                  onPressed: () => _applyPresetAmount(100000),
                  child: const Text('100.000'),
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
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(change.abs()),
                    style: TextStyle(
                      color: change >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text('Pembayaran Non-Tunai', style: AppTypography.titleMedium.copyWith(fontSize: 18)),
            const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          AppButton(
            text: 'Selesaikan Transaksi',
            onPressed: isPayDisabled
                ? null
                : () => _handlePayment(
                      grandTotal,
                      cartState.subtotal,
                      cartState.taxRate,
                      cartState.taxAmount,
                    ),
            icon: Icons.check_circle_outline_rounded,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    bool result = false;
    await AppDialog.show(
      context: context,
      title: 'Batal Pembayaran',
      message: 'Apakah Anda yakin ingin membatalkan pembayaran transaksi ini?',
      confirmText: 'Ya, Batal',
      cancelText: 'Tidak',
      isDestructive: true,
      onConfirm: () {
        result = true;
        Navigator.pop(context);
      },
    );
    return result;
  }
}
