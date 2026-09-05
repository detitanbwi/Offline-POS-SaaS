import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../core/utils/pdf_receipt_generator.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../../../core/widgets/app_receipt_preview_modal.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printing/printing.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cashier/application/cashier_notifier.dart';
import '../../application/sales_report_notifier.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const SalesReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesReportNotifierProvider.notifier).loadDailyReport(date: _selectedDate);
      ref.read(cashierNotifierProvider.notifier).loadCashiers();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      ref.read(salesReportNotifierProvider.notifier).setDate(picked);
    }
  }

  Future<void> _handlePrintReport(Map<String, dynamic> report) async {
    final paymentBreakdown = Map<String, double>.from(report['payment_breakdown'] as Map);
    final expectedCash = paymentBreakdown['Tunai'] ?? paymentBreakdown['Cash'] ?? 0.0;

    final actualCashController = TextEditingController(
      text: CurrencyFormatter.formatNumber(expectedCash),
    );

    final actualCash = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Input Kas Fisik (Tutup Shift)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expected Kas (Sistem): ${CurrencyFormatter.format(expectedCash)}', style: AppTypography.bodyMedium),
            SizedBox(height: 12),
            TextField(
              enableSuggestions: false, 
              autocorrect: false, 
              controller: actualCashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (val) {
                final cleanText = val.replaceAll('.', '').replaceAll(',', '');
                final parsed = double.tryParse(cleanText);
                if (parsed != null) {
                  final formatted = CurrencyFormatter.formatNumber(parsed);
                  if (actualCashController.text != formatted) {
                    actualCashController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                } else if (cleanText.isEmpty) {
                  actualCashController.clear();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Jumlah Uang Fisik di Laci (Actual)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final cleanText = actualCashController.text.replaceAll('.', '').replaceAll(',', '');
              final val = double.tryParse(cleanText) ?? expectedCash;
              Navigator.pop(context, val);
            },
            child: Text('Lanjutkan Cetak'),
          ),
        ],
      ),
    );

    if (actualCash == null) return;
    final selisihCash = actualCash - expectedCash;

    final activeUser = ref.read(authSessionProvider);
    final topProducts = List<Map<String, dynamic>>.from(report['top_products'] as List);
    final topModifiers = (report['top_modifiers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);

    final printerState = ref.read(printerNotifierProvider);
    final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
    final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

    final totalServiceCharge = (report['total_service_charge'] as num?)?.toDouble() ?? 0.0;
    final totalVoidCount = (report['total_void_count'] as int?) ?? 0;
    final totalVoidAmount = (report['total_void_amount'] as num?)?.toDouble() ?? 0.0;

    final textPreview = await ReceiptGenerator.formatReportTextPreview(
      dateStr: dateStr,
      totalSales: report['total_sales'] as double,
      totalTransactions: report['total_transactions'] as int,
      totalTax: report['total_tax'] as double,
      totalServiceCharge: totalServiceCharge,
      totalVoidCount: totalVoidCount,
      totalVoidAmount: totalVoidAmount,
      paymentBreakdown: paymentBreakdown,
      topProducts: topProducts,
      topModifiers: topModifiers,
      cashierNama: activeUser?.nama,
      expectedCash: expectedCash,
      actualCash: actualCash,
      selisihCash: selisihCash,
      charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
    );

    if (!mounted) return;
    AppReceiptPreviewModal.show(
      context,
      title: 'Rekapitulasi Shift Kasir',
      receiptTextPreview: textPreview,
      onGeneratePdf: () => PdfReceiptGenerator.generateReportPdf(
        dateStr: dateStr,
        totalSales: report['total_sales'] as double,
        totalTransactions: report['total_transactions'] as int,
        totalTax: report['total_tax'] as double,
        totalServiceCharge: totalServiceCharge,
        totalVoidCount: totalVoidCount,
        totalVoidAmount: totalVoidAmount,
        paymentBreakdown: paymentBreakdown,
        topProducts: topProducts,
        topModifiers: topModifiers,
        cashierNama: activeUser?.nama,
        expectedCash: expectedCash,
        actualCash: actualCash,
        selisihCash: selisihCash,
      ),
      onGenerateEscPosBytes: () => ReceiptGenerator.generateReportReceipt(
        dateStr: dateStr,
        totalSales: report['total_sales'] as double,
        totalTransactions: report['total_transactions'] as int,
        totalTax: report['total_tax'] as double,
        totalServiceCharge: totalServiceCharge,
        totalVoidCount: totalVoidCount,
        totalVoidAmount: totalVoidAmount,
        paymentBreakdown: paymentBreakdown,
        topProducts: topProducts,
        topModifiers: topModifiers,
        cashierNama: activeUser?.nama,
        expectedCash: expectedCash,
        actualCash: actualCash,
        selisihCash: selisihCash,
        paperSize: cashierPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: cashierPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: cashierPrinter?.autoCut ?? false,
      ),
    );
  }

  Future<Uint8List> _generatePdfBytes(Map<String, dynamic> report) async {
    final pdf = pw.Document();
    
    final storage = ref.read(secureStorageServiceProvider);
    final storeName = await storage.getStoreName() ?? 'Toko Kasir Offline';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Bisnis Commercial POS, Indonesia';
    final storePhone = await storage.getStorePhone() ?? '';
    
    final totalSales = report['total_sales'] as double;
    final totalTransactions = report['total_transactions'] as int;
    final totalServiceCharge = (report['total_service_charge'] as num?)?.toDouble() ?? 0.0;
    final totalTax = report['total_tax'] as double;
    final totalVoidCount = (report['total_void_count'] as int?) ?? 0;
    final totalVoidAmount = (report['total_void_amount'] as num?)?.toDouble() ?? 0.0;
    final paymentBreakdown = Map<String, double>.from(report['payment_breakdown'] as Map);
    final topProducts = List<Map<String, dynamic>>.from(report['top_products'] as List);

    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(storeName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 12)),
                      if (storePhone.isNotEmpty) pw.Text('Telp: $storePhone', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                
                // Title
                pw.Text('LAPORAN PENJUALAN HARIAN', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Tanggal Laporan: $formattedDate', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Waktu Cetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),

                // Ringkasan Keuangan
                pw.Text('Ringkasan Transaksi', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Parameter', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Nilai', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ]
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Omset Penjualan')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(CurrencyFormatter.format(totalSales))),
                      ]
                    ),
                    if (totalServiceCharge > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Service Charge')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(CurrencyFormatter.format(totalServiceCharge))),
                        ]
                      ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Pajak (PPN)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(CurrencyFormatter.format(totalTax))),
                      ]
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Jumlah Transaksi')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$totalTransactions')),
                      ]
                    ),
                    if (totalVoidCount > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Transaksi Dibatalkan (Void) ($totalVoidCount transaksi)')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(CurrencyFormatter.format(totalVoidAmount), style: const pw.TextStyle(color: PdfColors.red))),
                        ]
                      ),
                  ]
                ),
                pw.SizedBox(height: 20),

                // Metode Pembayaran
                pw.Text('Detail Metode Pembayaran', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Metode', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Akumulasi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ]
                    ),
                    ...paymentBreakdown.entries.map((entry) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.key)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(CurrencyFormatter.format(entry.value))),
                        ]
                      );
                    }),
                  ]
                ),
                pw.SizedBox(height: 20),

                // Produk Terlaris
                pw.Text('5 Produk Terlaris', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Nama Produk', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty Terjual', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Penjualan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ]
                    ),
                    ...topProducts.map((prod) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(prod['nama'] as String)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${prod['qty']}')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(CurrencyFormatter.format(prod['total'] as double))),
                        ]
                      );
                    }),
                  ]
                ),

                if (report['top_modifiers'] != null && (report['top_modifiers'] as List).isNotEmpty) ...[
                  pw.SizedBox(height: 20),
                  pw.Text('Rekap Varian & Topping Terjual', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Varian / Topping', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty Terjual', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Tambahan Pendapatan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ]
                      ),
                      ...(report['top_modifiers'] as List).map((mod) {
                        final m = mod as Map<String, dynamic>;
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(m['nama'] as String? ?? '-')),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${m['qty']}')),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(CurrencyFormatter.format((m['total'] as num?)?.toDouble() ?? 0.0))),
                          ]
                        );
                      }),
                    ]
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _exportToPDF(Map<String, dynamic> report) async {
    try {
      final pdfBytes = await _generatePdfBytes(report);
      final fileName = 'Laporan_Penjualan_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf';
      final savedFile = await FileSaverUtil.saveToDownloads(pdfBytes, fileName);
      
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'PDF Laporan berhasil disimpan:\n${savedFile.path}');

      // Buka dialog preview / cetak PDF sistem
      try {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: fileName,
        );
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Gagal membuat file PDF: $e');
    }
  }

  Future<void> _sharePDF(Map<String, dynamic> report) async {
    try {
      final pdfBytes = await _generatePdfBytes(report);
      final fileName = 'Laporan_Penjualan_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf';
      
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
        subject: 'Laporan Penjualan - ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Gagal membagikan file PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(salesReportNotifierProvider);
    final cashierState = ref.watch(cashierNotifierProvider);
    final authUser = ref.watch(authSessionProvider);
    final isOwner = authUser?.isOwner ?? false;
    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Filter Card
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tanggal Laporan',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13.sp),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Ubah Tanggal'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              if (isOwner && cashierState.allCashiers.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person_search_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Kasir:',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 12.sp),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: reportState.selectedCashierId,
                            isExpanded: true,
                            hint: const Text('Semua Kasir (Akumulasi)', style: TextStyle(fontSize: 13)),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Semua Kasir (Akumulasi)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              ...cashierState.allCashiers.map((cashier) {
                                return DropdownMenuItem<String?>(
                                  value: cashier.id,
                                  child: Text(
                                    '${cashier.nama}${cashier.isOwner == 1 ? " (Owner)" : ""}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              String? cashierName;
                              if (val != null) {
                                final matches = cashierState.allCashiers.where((x) => x.id == val);
                                if (matches.isNotEmpty) {
                                  cashierName = matches.first.nama;
                                }
                              }
                              ref.read(salesReportNotifierProvider.notifier).setCashier(val, cashierName);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (!isOwner && authUser != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Kasir:',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 12.sp),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        authUser.nama,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: reportState.isLoading
                ? const AppLoading(message: 'Membuat laporan...')
                : reportState.reportData == null
                    ? Center(
                        child: Text(
                          'Laporan tidak tersedia',
                          style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : _buildReportContent(context, reportState.reportData!),
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
        title: const Text('Laporan Penjualan Harian'),
        actions: [
          if (reportState.reportData != null && ((reportState.reportData!['total_transactions'] as int?) ?? 0) > 0)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Bagikan PDF Laporan',
              onPressed: () => _sharePDF(reportState.reportData!),
            ),
        ],
      ),
      body: SafeArea(
        child: content,
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, Map<String, dynamic> report) {
    final totalSales = report['total_sales'] as double;
    final totalTransactions = report['total_transactions'] as int;
    final totalServiceCharge = (report['total_service_charge'] as num?)?.toDouble() ?? 0.0;
    final totalTax = report['total_tax'] as double;
    final paymentBreakdown = report['payment_breakdown'] as Map<String, double>;
    final topProducts = report['top_products'] as List<Map<String, dynamic>>;
    final topModifiers = (report['top_modifiers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final isWide = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).orientation == Orientation.landscape;

    final overviewCards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Omset', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
              SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(totalSales),
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 18.sp,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Transaksi', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    SizedBox(height: 4),
                    Text(
                      '$totalTransactions',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 18.sp),
                    ),
                  ],
                ),
              ),
            ),
            if (totalServiceCharge > 0) ...[
              SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Service Charge', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(totalServiceCharge),
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 18.sp),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(width: 12),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Pajak (PPN)', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(totalTax),
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 18.sp),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if ((report['total_void_count'] as int? ?? 0) > 0) ...[
          SizedBox(height: 12),
          AppCard(
            color: AppColors.error.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaksi Dibatalkan (Void)', style: AppTypography.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('${report['total_void_count']} transaksi void (stok dikembalikan)', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary)),
                  ],
                ),
                Text(
                  CurrencyFormatter.format((report['total_void_amount'] as num?)?.toDouble() ?? 0.0),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 15.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Detail Pembayaran',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              if (paymentBreakdown.isEmpty)
                Text(
                  'Belum ada transaksi pembayaran.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                )
              else
                ...paymentBreakdown.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: AppTypography.bodyMedium),
                        Text(
                          CurrencyFormatter.format(entry.value),
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );

    final detailsCard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '5 Produk Terlaris',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              if (topProducts.isEmpty)
                Text(
                  'Belum ada produk yang terjual.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topProducts.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final prod = topProducts[index];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(prod['nama'] as String, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                              Text('${prod['qty']} porsi terjual', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(prod['total'] as double),
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        if (topModifiers.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekap Varian & Topping Terjual',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pendapatan varian/topping sudah otomatis masuk ke total omset produk di atas',
                            style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topModifiers.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final mod = topModifiers[index];
                    final double total = (mod['total'] as num?)?.toDouble() ?? 0.0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mod['nama'] as String? ?? '-', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                              Text('${mod['qty']}x dipilih', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
                            ],
                          ),
                        ),
                        Text(
                          total > 0 ? CurrencyFormatter.format(total) : 'Gratis',
                          style: AppTypography.bodyMedium.copyWith(
                            color: total > 0 ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        AppButton(
          text: 'Cetak Laporan Ringkasan',
          onPressed: totalTransactions == 0 ? null : () => _handlePrintReport(report),
          icon: Icons.print_rounded,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Unduh PDF',
                type: AppButtonType.secondary,
                onPressed: totalTransactions == 0 ? null : () => _exportToPDF(report),
                icon: Icons.download_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                text: 'Bagikan PDF',
                type: AppButtonType.secondary,
                onPressed: totalTransactions == 0 ? null : () => _sharePDF(report),
                icon: Icons.share_rounded,
              ),
            ),
          ],
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: SingleChildScrollView(child: overviewCards),
          ),
          SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(child: detailsCard),
          ),
        ],
      );
    } else {
      return ListView(
        children: [
          overviewCards,
          SizedBox(height: 20),
          detailsCard,
        ],
      );
    }
  }
}
