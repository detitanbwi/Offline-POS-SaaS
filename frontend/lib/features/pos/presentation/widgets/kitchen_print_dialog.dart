import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../features/product/application/product_notifier.dart';
import '../../../../features/category/application/category_notifier.dart';
import '../../../../features/printer/application/printer_notifier.dart';
import '../../../../features/printer/domain/models/printer_config.dart';
import '../../../pos/domain/models/order.dart';
import '../../../pos/domain/models/order_item.dart';

class KitchenPrintDialog {
  /// Entry point to print kitchen tickets.
  /// If only 1 kitchen printer exists, prints directly.
  /// If > 1 kitchen printers exist, displays selection dialog for cashier.
  static Future<bool> showOrPrint({
    required BuildContext context,
    required WidgetRef ref,
    required OrderModel order,
    required List<OrderItemModel> itemsToPrint,
    String? waveInfo,
    String? cashierNama,
  }) async {
    if (itemsToPrint.isEmpty) {
      if (context.mounted) {
        AppSnackbar.showWarning(context, 'Tidak ada item pesanan yang perlu dicetak ke dapur.');
      }
      return false;
    }

    final printerNotifier = ref.read(printerNotifierProvider.notifier);
    await printerNotifier.loadPrinters();
    final printerState = ref.read(printerNotifierProvider);
    final kitchenPrinters = printerState.kitchenPrinters;

    if (kitchenPrinters.isEmpty) {
      if (context.mounted) {
        AppSnackbar.showWarning(
          context,
          'Belum ada printer dapur yang terkonfigurasi di Pengaturan.',
        );
      }
      return false;
    }

    // Single Kitchen Printer -> Direct Print
    if (kitchenPrinters.length == 1) {
      final targetPrinter = kitchenPrinters.first;
      return await _printToSingleKitchen(
        context: context,
        ref: ref,
        printer: targetPrinter,
        order: order,
        items: itemsToPrint,
        waveInfo: waveInfo,
        cashierNama: cashierNama,
        showSuccessSnackbar: true,
      );
    }

    // Multiple Kitchen Printers (>1) -> Show Picker Dialog
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _KitchenPrinterSelectionModal(
        order: order,
        itemsToPrint: itemsToPrint,
        kitchenPrinters: kitchenPrinters,
        waveInfo: waveInfo,
        cashierNama: cashierNama,
      ),
    );

    return result ?? false;
  }

  /// Internal helper to print to a single kitchen printer
  static Future<bool> _printToSingleKitchen({
    required BuildContext context,
    required WidgetRef ref,
    required PrinterConfigModel printer,
    required OrderModel order,
    required List<OrderItemModel> items,
    String? waveInfo,
    String? cashierNama,
    bool showSuccessSnackbar = false,
  }) async {
    try {
      final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
        order: order,
        itemsToPrint: items,
        waveInfo: waveInfo,
        cashierNama: cashierNama,
        paperSize: printer.escPosPaperSize,
        charsPerLine: printer.effectiveCharsPerLine,
        autoCut: printer.autoCut,
      );

      final success = await ref
          .read(printerNotifierProvider.notifier)
          .printBytes(printer, receiptBytes);

      if (context.mounted && showSuccessSnackbar) {
        if (success) {
          AppSnackbar.showSuccess(
            context,
            'Pesanan dapur berhasil dicetak ke "${printer.displayName}".',
          );
        } else {
          AppSnackbar.showError(
            context,
            'Gagal mencetak ke printer dapur "${printer.displayName}". Periksa koneksi Bluetooth.',
          );
        }
      }
      return success;
    } catch (e) {
      if (context.mounted && showSuccessSnackbar) {
        AppSnackbar.showError(context, 'Error mencetak tiket dapur: $e');
      }
      return false;
    }
  }
}

class _KitchenPrinterSelectionModal extends ConsumerStatefulWidget {
  final OrderModel order;
  final List<OrderItemModel> itemsToPrint;
  final List<PrinterConfigModel> kitchenPrinters;
  final String? waveInfo;
  final String? cashierNama;

  const _KitchenPrinterSelectionModal({
    required this.order,
    required this.itemsToPrint,
    required this.kitchenPrinters,
    this.waveInfo,
    this.cashierNama,
  });

  @override
  ConsumerState<_KitchenPrinterSelectionModal> createState() =>
      _KitchenPrinterSelectionModalState();
}

class _KitchenPrinterSelectionModalState
    extends ConsumerState<_KitchenPrinterSelectionModal> {
  late Set<String> _selectedPrinterIds;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    // By default, select all printers
    _selectedPrinterIds = widget.kitchenPrinters.map((p) => p.id).toSet();
  }

  /// Filters items for a specific kitchen printer according to its mapped categories
  List<OrderItemModel> _getItemsForPrinter(
    PrinterConfigModel printer,
    Map<String, String> productCategoryMap,
  ) {
    if (printer.categoryIds.isEmpty) {
      // No category filter -> printer gets all items
      return widget.itemsToPrint;
    }

    return widget.itemsToPrint.where((item) {
      if (item.isManual) return true; // Manual items included everywhere
      final catId = productCategoryMap[item.produkId];
      if (catId == null) return true; // Fallback if uncategorized
      return printer.categoryIds.contains(catId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productNotifierProvider).allProducts;
    final categories = ref.watch(categoryNotifierProvider).allCategories;

    // Create lookup map: productId -> categoryId
    final productCategoryMap = <String, String>{};
    for (final p in products) {
      if (p.kategoriId.isNotEmpty) {
        productCategoryMap[p.id] = p.kategoriId;
      }
    }

    // Category name lookup map
    final categoryNameMap = <String, String>{};
    for (final c in categories) {
      categoryNameMap[c.id] = c.nama;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: const Icon(Icons.soup_kitchen_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kirim Pesanan ke Dapur',
                  style: AppTypography.titleMedium.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Pilih printer dapur tujuan cetak (${widget.kitchenPrinters.length} printer):',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.kitchenPrinters.map((printer) {
              final isChecked = _selectedPrinterIds.contains(printer.id);
              final matchingItems = _getItemsForPrinter(printer, productCategoryMap);

              final categoryNames = printer.categoryIds
                  .map((id) => categoryNameMap[id] ?? '')
                  .where((name) => name.isNotEmpty)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  borderSide: BorderSide(
                    color: isChecked ? AppColors.primary : AppColors.divider,
                    width: isChecked ? 1.5 : 1,
                  ),
                  color: isChecked ? AppColors.primaryContainer.withValues(alpha: 0.3) : AppColors.surface,
                  padding: const EdgeInsets.all(12),
                  child: InkWell(
                    onTap: _isPrinting
                        ? null
                        : () {
                            setState(() {
                              if (isChecked) {
                                _selectedPrinterIds.remove(printer.id);
                              } else {
                                _selectedPrinterIds.add(printer.id);
                              }
                            });
                          },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
                              onChanged: _isPrinting
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPrinterIds.add(printer.id);
                                        } else {
                                          _selectedPrinterIds.remove(printer.id);
                                        }
                                      });
                                    },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    printer.displayName,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5.sp,
                                      color: isChecked ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Device: ${printer.name}',
                                    style: TextStyle(fontSize: 10.5.sp, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: matchingItems.isNotEmpty
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.disabled.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                '${matchingItems.length} Item',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: matchingItems.isNotEmpty ? AppColors.primary : AppColors.disabled,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (categoryNames.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 36.0),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: categoryNames.map((cName) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.divider.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(cName, style: TextStyle(fontSize: 9.5.sp, color: AppColors.textSecondary)),
                              )).toList(),
                            ),
                          ),
                        ],
                        if (matchingItems.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 36.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: matchingItems.map((item) => Text(
                                '• ${item.qty}x ${item.produkNama}',
                                style: TextStyle(fontSize: 11.sp, color: AppColors.textPrimary),
                              )).toList(),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 36.0),
                            child: Text(
                              '(Tidak ada item yang cocok dengan kategori printer ini)',
                              style: TextStyle(fontSize: 10.5.sp, color: AppColors.disabled, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
          onPressed: (_isPrinting || _selectedPrinterIds.isEmpty)
              ? null
              : () async {
                  setState(() => _isPrinting = true);
                  int successCount = 0;
                  int failedCount = 0;

                  for (final printerId in _selectedPrinterIds) {
                    final printer = widget.kitchenPrinters.firstWhere((p) => p.id == printerId);
                    final matchingItems = _getItemsForPrinter(printer, productCategoryMap);

                    if (matchingItems.isEmpty) continue;

                    final success = await KitchenPrintDialog._printToSingleKitchen(
                      context: context,
                      ref: ref,
                      printer: printer,
                      order: widget.order,
                      items: matchingItems,
                      waveInfo: widget.waveInfo,
                      cashierNama: widget.cashierNama,
                      showSuccessSnackbar: false,
                    );

                    if (success) {
                      successCount++;
                    } else {
                      failedCount++;
                    }
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                    if (successCount > 0 && failedCount == 0) {
                      AppSnackbar.showSuccess(
                        context,
                        'Pesanan dapur berhasil dikirim ke $successCount printer.',
                      );
                    } else if (successCount > 0 && failedCount > 0) {
                      AppSnackbar.showWarning(
                        context,
                        'Berhasil cetak ke $successCount printer, namun $failedCount printer gagal.',
                      );
                    } else {
                      AppSnackbar.showError(
                        context,
                        'Gagal mencetak ke printer dapur yang dipilih.',
                      );
                    }
                  }
                },
          child: _isPrinting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Cetak ke (${_selectedPrinterIds.length}) Dapur'),
        ),
      ],
    );
  }
}
