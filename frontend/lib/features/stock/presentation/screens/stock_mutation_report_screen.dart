import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/services/secure_storage_service.dart';
import '../../../product/application/product_notifier.dart';
import '../../../product/domain/models/product.dart';
import '../../application/stock_notifier.dart';
import '../../domain/models/stock_in.dart';

class StockMutationReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const StockMutationReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<StockMutationReportScreen> createState() => _StockMutationReportScreenState();
}

class _StockMutationReportScreenState extends ConsumerState<StockMutationReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedProductId;
  String _selectedType = 'ALL'; // ALL, in, out

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productNotifierProvider.notifier).loadProducts();
      ref.read(stockNotifierProvider.notifier).loadStockIn();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  List<StockIn> _getFilteredMutations(List<StockIn> allMutations) {
    return allMutations.where((m) {
      DateTime mutationDate;
      try {
        mutationDate = DateTime.parse(m.tanggal);
      } catch (_) {
        mutationDate = m.createdAt;
      }

      final startMidnight = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endMidnight = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      if (mutationDate.isBefore(startMidnight) || mutationDate.isAfter(endMidnight)) {
        return false;
      }

      if (_selectedProductId != null && m.produkId != _selectedProductId) {
        return false;
      }

      if (_selectedType != 'ALL' && m.type.toLowerCase() != _selectedType.toLowerCase()) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        DateTime dateA;
        DateTime dateB;
        try { dateA = DateTime.parse(a.tanggal); } catch (_) { dateA = a.createdAt; }
        try { dateB = DateTime.parse(b.tanggal); } catch (_) { dateB = b.createdAt; }
        return dateB.compareTo(dateA);
      });
  }

  Future<void> _exportPdf(List<StockIn> mutations, List<Product> products) async {
    final pdf = pw.Document();
    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'Toko Kasir Pro';

    final productMap = {for (var p in products) p.id: p.nama};
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LAPORAN MUTASI STOK', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text(storeName, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Periode: ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Tanggal', 'Produk', 'Jenis Mutasi', 'Qty', 'Catatan / Alasan'],
              data: mutations.map((m) {
                final pName = productMap[m.produkId] ?? 'Produk (${m.produkId})';
                final isPositive = m.type.toLowerCase() == 'in' || m.type.toLowerCase() == 'void';
                final qtyStr = '${isPositive ? "+" : "-"}${m.qty}';
                final typeStr = m.type.toUpperCase() == 'IN' ? 'MASUK' : (m.type.toUpperCase() == 'OUT' ? 'KELUAR' : m.type.toUpperCase());
                final noteStr = (m.catatan != null && m.catatan!.isNotEmpty) ? m.catatan! : '-';
                return [
                  m.tanggal,
                  pName,
                  typeStr,
                  qtyStr,
                  noteStr,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Mutasi_Stok_${DateFormat('yyyyMMdd').format(_startDate)}_sd_${DateFormat('yyyyMMdd').format(_endDate)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockNotifierProvider);
    final productState = ref.watch(productNotifierProvider);

    final productMap = {for (var p in productState.allProducts) p.id: p};
    final filteredMutations = _getFilteredMutations(stockState.allStockIn);

    final totalIn = filteredMutations.where((m) => m.type.toLowerCase() == 'in' || m.type.toLowerCase() == 'void').fold<int>(0, (sum, m) => sum + m.qty);
    final totalOut = filteredMutations.where((m) => m.type.toLowerCase() == 'out' || m.type.toLowerCase() == 'sale').fold<int>(0, (sum, m) => sum + m.qty);

    Widget content = Column(
      children: [
        // Filter & Summary Header
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: AppCard(
            padding: EdgeInsets.all(14.r),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDateRange,
                        borderRadius: BorderRadius.circular(10.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(10.r),
                            color: AppColors.surface,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range_rounded, size: 18.r, color: AppColors.primary),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton.filled(
                      onPressed: filteredMutations.isEmpty
                          ? null
                          : () => _exportPdf(filteredMutations, productState.allProducts),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      tooltip: 'Ekspor PDF',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedProductId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                          labelText: 'Filter Produk',
                          labelStyle: TextStyle(fontSize: 11.sp),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Semua Produk', style: TextStyle(fontSize: 12))),
                          ...productState.allProducts
                              .where((p) => !p.isPackage && p.stok != -1)
                              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nama, style: const TextStyle(fontSize: 12)))),
                        ],
                        onChanged: (val) => setState(() => _selectedProductId = val),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                          labelText: 'Jenis Mutasi',
                          labelStyle: TextStyle(fontSize: 11.sp),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Semua Jenis', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'in', child: Text('Masuk (+)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'out', child: Text('Keluar (-)', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) => setState(() => _selectedType = val ?? 'ALL'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                // Summary Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Masuk:', style: TextStyle(fontSize: 11.sp, color: AppColors.success, fontWeight: FontWeight.bold)),
                            Text('+$totalIn pcs', style: TextStyle(fontSize: 12.sp, color: AppColors.success, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Keluar:', style: TextStyle(fontSize: 11.sp, color: AppColors.error, fontWeight: FontWeight.bold)),
                            Text('-$totalOut pcs', style: TextStyle(fontSize: 12.sp, color: AppColors.error, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Mutasi List
        Expanded(
          child: stockState.isLoading
              ? const AppLoading(message: 'Memuat riwayat mutasi...')
              : filteredMutations.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.swap_vert_rounded,
                      title: 'Tidak Ada Riwayat Mutasi',
                      description: 'Tidak ada data mutasi stok pada periode dan filter yang dipilih.',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                      itemCount: filteredMutations.length,
                      itemBuilder: (context, index) {
                        final m = filteredMutations[index];
                        final prod = productMap[m.produkId];
                        final isPositive = m.type.toLowerCase() == 'in' || m.type.toLowerCase() == 'void';

                        return Card(
                          elevation: 0.5,
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12.r),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: isPositive
                                        ? AppColors.success.withValues(alpha: 0.12)
                                        : AppColors.error.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(
                                    isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    color: isPositive ? AppColors.success : AppColors.error,
                                    size: 20.r,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prod?.nama ?? (m.produkNama ?? 'Produk #${m.produkId.substring(0, 6)}'),
                                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Tanggal: ${m.tanggal}',
                                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                      ),
                                      if (m.catatan != null && m.catatan!.isNotEmpty) ...[
                                        SizedBox(height: 2.h),
                                        Text(
                                          'Catatan: ${m.catatan}',
                                          style: AppTypography.bodySmall.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isPositive ? "+" : "-"}${m.qty} pcs',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isPositive ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(color: AppColors.divider),
                                      ),
                                      child: Text(
                                        m.type.toUpperCase() == 'IN'
                                            ? 'MASUK'
                                            : (m.type.toUpperCase() == 'OUT' ? 'KELUAR' : m.type.toUpperCase()),
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Laporan Mutasi Stok'),
      ),
      body: SafeArea(child: content),
    );
  }
}
