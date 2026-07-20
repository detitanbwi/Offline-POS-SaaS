import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../core/utils/pdf_receipt_generator.dart';
import '../../../../core/widgets/app_receipt_preview_modal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../application/transaction_history_notifier.dart';
import '../../../pos/domain/models/transaction.dart';


class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionHistoryNotifierProvider.notifier).loadTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showReceiptDetail(BuildContext context, TransactionHeader tx) async {
    // Show loading dialog while fetching items
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final items = await ref.read(transactionHistoryNotifierProvider.notifier).getItems(tx.id);

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    final printerState = ref.read(printerNotifierProvider);
    final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
    final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

    final textPreview = await ReceiptGenerator.formatCashierTextPreview(
      transaction: tx,
      items: items,
      charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
    );

    if (!mounted) return;
    AppReceiptPreviewModal.show(
      context,
      title: 'Struk Pembayaran',
      receiptTextPreview: textPreview,
      onGeneratePdf: () => PdfReceiptGenerator.generateCashierReceiptPdf(
        transaction: tx,
        items: items,
      ),
      onGenerateEscPosBytes: () => ReceiptGenerator.generateCashierReceipt(
        transaction: tx,
        items: items,
        paperSize: cashierPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: cashierPrinter?.autoCut ?? false,
      ),
    );
  }

  void _handleVoidTransaction(BuildContext context, TransactionHeader tx) {
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Otorisasi Pembatalan (Void)', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Masukkan PIN Master Pemilik untuk mengotorisasi pembatalan transaksi ini.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: AppSpacing.m),
                AppTextField(
                  controller: pinController,
                  labelText: 'PIN Master Pemilik',
                  hintText: 'Masukkan 6 digit PIN Master',
                  prefixIcon: Icons.lock_rounded,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  validator: (val) {
                    if (val == null || val.length != 6) {
                      return 'PIN harus tepat 6 digit';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final enteredPin = pinController.text;
                  const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
                  final bytesBytes = utf8.encode(enteredPin + salt);
                  final enteredHash = sha256.convert(bytesBytes).toString();

                  final storage = ref.read(secureStorageServiceProvider);
                  final savedHashedPin = await storage.getLocalPIN();

                  if (!context.mounted) return;
                  Navigator.pop(context); // Close dialog

                  if (enteredHash == savedHashedPin) {
                    final notifier = ref.read(transactionHistoryNotifierProvider.notifier);
                    final success = await notifier.voidTransaction(tx.id);
                    
                    if (!context.mounted) return;
                    if (success) {
                      AppSnackbar.showSuccess(context, 'Transaksi ${tx.nomorTransaksi} berhasil dibatalkan (Void). Stok barang dikembalikan.');
                    } else {
                      final state = ref.read(transactionHistoryNotifierProvider);
                      AppSnackbar.showError(context, state.errorMessage ?? 'Gagal membatalkan transaksi.');
                    }
                  } else {
                    AppSnackbar.showError(context, 'Otorisasi gagal! PIN Master Pemilik salah.');
                  }
                }
              },
              child: const Text('Otorisasikan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryNotifierProvider);
    final notifier = ref.read(transactionHistoryNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: AppTextField(
                controller: _searchController,
                labelText: 'Cari Struk Transaksi',
                prefixIcon: Icons.search,
                onChanged: (val) => notifier.setSearchQuery(val),
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat riwayat transaksi...')
                  : state.filteredTransactions.isEmpty
                      ? AppEmptyState(
                          title: 'Riwayat Transaksi Kosong',
                          description: _searchController.text.isNotEmpty
                              ? 'Tidak ada struk transaksi yang cocok.'
                              : 'Belum ada transaksi tersimpan.',
                          icon: Icons.history_toggle_off_rounded,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          itemCount: state.filteredTransactions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = state.filteredTransactions[index];
                            final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.createdAt);
                            
                            return AppCard(
                              onTap: () => _showReceiptDetail(context, tx),
                              padding: const EdgeInsets.all(16),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.nomorTransaksi,
                                          style: AppTypography.titleMedium.copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Pembayaran: ${tx.paymentMethodNama} • $timeStr',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(tx.grandTotal),
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 15,
                                    ),
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
    );
  }
}
