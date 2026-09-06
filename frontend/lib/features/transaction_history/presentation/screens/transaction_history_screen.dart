// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import '../../../security/presentation/providers/security_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';


class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const TransactionHistoryScreen({super.key, this.isEmbedded = false});

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
      builder: (context) => Center(child: CircularProgressIndicator()),
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
    final formKey = GlobalKey<FormState>();
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        String? errorMessage;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Otorisasi Pembatalan (Void)', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Masukkan PIN Master Pemilik untuk mengotorisasi pembatalan transaksi ini.',
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                    ),
                    SizedBox(height: AppSpacing.m),
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
                    if (errorMessage != null) ...[
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          errorMessage!,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final enteredPin = pinController.text.trim();
                            const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
                            final bytesBytes = utf8.encode(enteredPin + salt);
                            final enteredHash = sha256.convert(bytesBytes).toString();

                            setDialogState(() {
                              isSubmitting = true;
                              errorMessage = null;
                            });

                            // 1. Cek Local PIN di SecureStorage (PIN Owner saat setup/login)
                            final storage = ref.read(secureStorageServiceProvider);
                            final savedLocalPin = await storage.getLocalPIN();
                            bool isAuthorized = savedLocalPin != null && (savedLocalPin == enteredHash || savedLocalPin == enteredPin);

                            // 2. Cek Master PIN Keamanan jika belum authorized
                            if (!isAuthorized) {
                              try {
                                isAuthorized = await ref.read(securityRepositoryProvider).validateMasterPin(enteredPin);
                              } catch (_) {}
                            }

                            if (!isAuthorized) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorMessage = 'Otorisasi gagal! PIN Master Pemilik salah.';
                              });
                              return;
                            }

                            final notifier = ref.read(transactionHistoryNotifierProvider.notifier);
                            final success = await notifier.voidTransaction(tx.id);

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext); // Tutup Dialog

                            if (context.mounted) {
                              if (success) {
                                AppSnackbar.showSuccess(context, 'Transaksi ${tx.nomorTransaksi} berhasil dibatalkan (Void). Stok barang dikembalikan.');
                              } else {
                                final state = ref.read(transactionHistoryNotifierProvider);
                                AppSnackbar.showError(context, state.errorMessage ?? 'Gagal membatalkan transaksi.');
                              }
                            }
                          }
                        },
                  child: isSubmitting
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Otorisasikan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final state = ref.read(transactionHistoryNotifierProvider);
    DateTimeRange? initialRange;
    if (state.startDate != null && state.endDate != null) {
      initialRange = DateTimeRange(start: state.startDate!, end: state.endDate!);
    } else if (state.startDate != null) {
      initialRange = DateTimeRange(start: state.startDate!, end: state.startDate!);
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih Rentang Tanggal Transaksi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      saveText: 'Terapkan',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(transactionHistoryNotifierProvider.notifier).setDateRange(picked.start, picked.end);
    }
  }

  bool _isTodaySelected(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return false;
    final now = DateTime.now();
    final isStartToday = startDate.year == now.year && startDate.month == now.month && startDate.day == now.day;
    final isEndToday = endDate.year == now.year && endDate.month == now.month && endDate.day == now.day;
    return isStartToday && isEndToday;
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Semua Tanggal';
    if (start != null && end != null) {
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return DateFormat('dd MMMM yyyy', 'id_ID').format(start);
      }
      if (start.year == end.year) {
        return '${DateFormat('dd MMM', 'id_ID').format(start)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(end)}';
      }
      return '${DateFormat('dd/MM/yy', 'id_ID').format(start)} - ${DateFormat('dd/MM/yy', 'id_ID').format(end)}';
    }
    if (start != null) return 'Dari ${DateFormat('dd MMM yyyy', 'id_ID').format(start)}';
    return 'Sampai ${DateFormat('dd MMM yyyy', 'id_ID').format(end!)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryNotifierProvider);
    final notifier = ref.read(transactionHistoryNotifierProvider.notifier);
    final hasDateFilter = state.startDate != null || state.endDate != null;

    final content = Column(
      children: [
        // Search & Date Filter Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 10),
          child: Column(
            children: [
                  AppTextField(
                    controller: _searchController,
                    labelText: 'Cari Struk Transaksi',
                    hintText: 'Cari nomor struk atau metode...',
                    prefixIcon: Icons.search,
                    onChanged: (val) => notifier.setSearchQuery(val),
                    debounceDuration: const Duration(milliseconds: 300),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Date Selector Button (Date Range)
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDateRange(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: hasDateFilter ? AppColors.primary : AppColors.divider,
                                width: hasDateFilter ? 1.5 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: hasDateFilter
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : AppColors.surface,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: hasDateFilter ? AppColors.primary : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDateRange(state.startDate, state.endDate),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.normal,
                                      color: hasDateFilter ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasDateFilter)
                                  GestureDetector(
                                    onTap: () => notifier.setDateRange(null, null),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.black87),
                                    ),
                                  )
                                else
                                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Quick Filter "Hari Ini"
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          side: BorderSide(
                            color: _isTodaySelected(state.startDate, state.endDate) ? AppColors.primary : AppColors.divider,
                          ),
                          backgroundColor: _isTodaySelected(state.startDate, state.endDate)
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (_isTodaySelected(state.startDate, state.endDate)) {
                            notifier.setDateRange(null, null);
                          } else {
                            final now = DateTime.now();
                            notifier.setDateRange(now, now);
                          }
                        },
                        icon: Icon(
                          _isTodaySelected(state.startDate, state.endDate) ? Icons.check_rounded : Icons.today_rounded,
                          size: 16,
                          color: _isTodaySelected(state.startDate, state.endDate) ? AppColors.primary : AppColors.textSecondary,
                        ),
                        label: Text(
                          'Hari Ini',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: _isTodaySelected(state.startDate, state.endDate) ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: _isTodaySelected(state.startDate, state.endDate) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat riwayat transaksi...')
                  : state.filteredTransactions.isEmpty
                      ? AppEmptyState(
                          title: 'Riwayat Transaksi Kosong',
                          description: state.selectedDate != null || _searchController.text.isNotEmpty
                              ? 'Tidak ada transaksi yang cocok dengan filter.'
                              : 'Belum ada transaksi tersimpan.',
                          icon: Icons.history_toggle_off_rounded,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          itemCount: state.filteredTransactions.length,
                          separatorBuilder: (context, index) => SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = state.filteredTransactions[index];
                            final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.createdAt);
                            
                            final isVoided = tx.status == 'voided';
                            
                            return AppCard(
                              onTap: () => _showReceiptDetail(context, tx),
                              padding: const EdgeInsets.all(16),
                              borderSide: BorderSide(
                                color: isVoided ? AppColors.error.withValues(alpha: 0.3) : AppColors.divider,
                              ),
                              color: isVoided ? Colors.red.shade50.withValues(alpha: 0.3) : Colors.white,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isVoided ? Colors.grey.shade200 : AppColors.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: isVoided ? Colors.grey : AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                         Wrap(
                                           crossAxisAlignment: WrapCrossAlignment.center,
                                           spacing: 6,
                                           runSpacing: 4,
                                           children: [
                                             Text(
                                               tx.nomorTransaksi,
                                               style: AppTypography.titleMedium.copyWith(
                                                 fontSize: 14.sp,
                                                 decoration: isVoided ? TextDecoration.lineThrough : null,
                                                 color: isVoided ? AppColors.textSecondary : AppColors.textPrimary,
                                               ),
                                             ),
                                             if (isVoided)
                                               Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                 decoration: BoxDecoration(
                                                   color: AppColors.error.withValues(alpha: 0.1),
                                                   borderRadius: BorderRadius.circular(6),
                                                 ),
                                                 child: Text(
                                                   'VOID',
                                                   style: TextStyle(
                                                     color: AppColors.error,
                                                     fontSize: 10.sp,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                               ),
                                           ],
                                         ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Kasir: ${tx.cashierNama != null && tx.cashierNama!.isNotEmpty ? tx.cashierNama : "-"} • ${tx.paymentMethodNama} • $timeStr',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(tx.grandTotal),
                                    style: AppTypography.titleMedium.copyWith(
                                      color: isVoided ? AppColors.textSecondary : AppColors.primary,
                                      fontSize: 15.sp,
                                      decoration: isVoided ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      Icons.block_rounded,
                                      color: isVoided ? Colors.grey.shade400 : AppColors.error,
                                      size: 20,
                                    ),
                                    tooltip: isVoided ? 'Transaksi Sudah Dibatalkan' : 'Batal Transaksi (Void)',
                                    onPressed: isVoided ? null : () => _handleVoidTransaction(context, tx),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        );

    if (widget.isEmbedded) {
      return SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: SafeArea(
        child: content,
      ),
    );
  }
}
