import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
import '../../../printer/application/printer_notifier.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/sales_report_notifier.dart';


class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesReportNotifierProvider.notifier).loadDailyReport(_selectedDate);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      ref.read(salesReportNotifierProvider.notifier).loadDailyReport(picked);
    }
  }

  Future<void> _handlePrintReport(Map<String, dynamic> report) async {
    final paymentBreakdown = Map<String, double>.from(report['payment_breakdown'] as Map);
    final expectedCash = paymentBreakdown['Tunai'] ?? (report['total_sales'] as double? ?? 0.0);

    final actualCashController = TextEditingController(text: expectedCash.toInt().toString());

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
              controller: actualCashController,
              keyboardType: TextInputType.number,
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
              final val = double.tryParse(actualCashController.text) ?? expectedCash;
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
    final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);

    final printerState = ref.read(printerNotifierProvider);
    final cashierPrinterList = printerState.configuredPrinters.where((p) => p.isCashier).toList();
    final cashierPrinter = cashierPrinterList.isNotEmpty ? cashierPrinterList.first : null;

    final textPreview = await ReceiptGenerator.formatReportTextPreview(
      dateStr: dateStr,
      totalSales: report['total_sales'] as double,
      totalTransactions: report['total_transactions'] as int,
      totalTax: report['total_tax'] as double,
      paymentBreakdown: paymentBreakdown,
      topProducts: topProducts,
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
        paymentBreakdown: paymentBreakdown,
        topProducts: topProducts,
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
        paymentBreakdown: paymentBreakdown,
        topProducts: topProducts,
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

  Future<void> _exportToPDF(Map<String, dynamic> report) async {
    final pdf = pw.Document();
    
    final storage = ref.read(secureStorageServiceProvider);
    final storeName = await storage.getStoreName() ?? 'Toko Kasir Offline';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Bisnis Commercial POS, Indonesia';
    final storePhone = await storage.getStorePhone() ?? '';
    
    final totalSales = report['total_sales'] as double;
    final totalTransactions = report['total_transactions'] as int;
    final totalTax = report['total_tax'] as double;
    final paymentBreakdown = Map<String, double>.from(report['payment_breakdown'] as Map);
    final topProducts = List<Map<String, dynamic>>.from(report['top_products'] as List);

    final formattedDate = DateFormat('dd MMMM yyyy').format(_selectedDate);

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
                pw.Text('Waktu Cetak: ${DateTime.now().toString().split('.').first}', style: const pw.TextStyle(fontSize: 10)),
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
              ],
            ),
          );
        },
      ),
    );

    try {
      final pdfBytes = await pdf.save();
      final fileName = 'Laporan_Penjualan_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf';
      final savedFile = await FileSaverUtil.saveToDownloads(pdfBytes, fileName);
      
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'PDF Laporan berhasil disimpan di folder Downloads:\n${savedFile.path}');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Gagal membuat file PDF: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(salesReportNotifierProvider);
    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Laporan Penjualan Harian'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tanggal Laporan', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                      Text(formattedDate, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: Icon(Icons.calendar_month_rounded),
                    label: Text('Ubah Tanggal'),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.l),
              
              Expanded(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, Map<String, dynamic> report) {
    final totalSales = report['total_sales'] as double;
    final totalTransactions = report['total_transactions'] as int;
    final totalTax = report['total_tax'] as double;
    final paymentBreakdown = report['payment_breakdown'] as Map<String, double>;
    final topProducts = report['top_products'] as List<Map<String, dynamic>>;

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
        SizedBox(height: 24),
        AppButton(
          text: 'Cetak Laporan Ringkasan',
          onPressed: totalTransactions == 0 ? null : () => _handlePrintReport(report),
          icon: Icons.print_rounded,
        ),
        SizedBox(height: 8),
        AppButton(
          text: 'Unduh / Ekspor Laporan PDF',
          type: AppButtonType.secondary,
          onPressed: totalTransactions == 0 ? null : () => _exportToPDF(report),
          icon: Icons.picture_as_pdf_rounded,
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
