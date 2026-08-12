import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_snackbar.dart';
import '../../features/printer/application/printer_notifier.dart';
import '../../features/printer/domain/models/printer_config.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppReceiptPreviewModal extends ConsumerWidget {
  final String title;
  final String receiptTextPreview;
  final String? printerType; // 'kitchen' or 'cashier'
  final Future<Uint8List> Function() onGeneratePdf;
  final Future<List<int>> Function() onGenerateEscPosBytes;

  const AppReceiptPreviewModal({
    super.key,
    required this.title,
    required this.receiptTextPreview,
    this.printerType,
    required this.onGeneratePdf,
    required this.onGenerateEscPosBytes,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String receiptTextPreview,
    String? printerType,
    required Future<Uint8List> Function() onGeneratePdf,
    required Future<List<int>> Function() onGenerateEscPosBytes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppReceiptPreviewModal(
        title: title,
        receiptTextPreview: receiptTextPreview,
        printerType: printerType,
        onGeneratePdf: onGeneratePdf,
        onGenerateEscPosBytes: onGenerateEscPosBytes,
      ),
    );
  }

  Future<void> _handlePrintThermal(BuildContext context, WidgetRef ref) async {
    final printerState = ref.read(printerNotifierProvider);
    final hasPrinter = printerState.configuredPrinters.isNotEmpty;

    if (!hasPrinter) {
      AppSnackbar.showWarning(
        context,
        'Belum ada printer Bluetooth terkonfigurasi. Menggunakan pratinjau simulator.',
      );
    }

    final bytes = await onGenerateEscPosBytes();

    if (hasPrinter) {
      final List<PrinterConfigModel> targetList;
      if (printerType == 'kitchen') {
        targetList = printerState.configuredPrinters.where((p) => p.isKitchen).toList();
      } else if (printerType == 'cashier') {
        targetList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
      } else {
        targetList = printerState.configuredPrinters;
      }

      final targetPrinter = targetList.isNotEmpty ? targetList.first : printerState.configuredPrinters.first;
      final success = await ref.read(printerNotifierProvider.notifier).printBytes(targetPrinter, bytes);
      if (!context.mounted) return;
      if (success) {
        AppSnackbar.showSuccess(context, 'Berhasil mencetak ke printer thermal (${targetPrinter.name}).');
        Navigator.pop(context);
      } else {
        AppSnackbar.showError(context, 'Gagal mencetak ke printer Bluetooth.');
      }
    } else {
      if (!context.mounted) return;
      AppSnackbar.showSuccess(context, 'Simulasi cetak thermal berhasil disimulasikan (${bytes.length} bytes).');
      Navigator.pop(context);
    }
  }

  Future<void> _handleOpenPdf(BuildContext context) async {
    try {
      final pdfBytes = await onGeneratePdf();
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${title.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Gagal memuat pratinjau PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: AppTypography.titleLarge.copyWith(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Thermal Simulation Paper View
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: Text(
                          receiptTextPreview,
                          softWrap: false,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.3,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Pratinjau / Buka PDF',
                    type: AppButtonType.secondary,
                    icon: Icons.picture_as_pdf_rounded,
                    onPressed: () => _handleOpenPdf(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: 'Cetak Thermal',
                    icon: Icons.print_rounded,
                    onPressed: () => _handlePrintThermal(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
