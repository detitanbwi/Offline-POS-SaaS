import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../database/pos_database.dart';
import '../../features/pos/domain/models/order.dart';
import '../../features/pos/domain/models/order_item.dart';
import '../../features/pos/domain/models/transaction.dart';
import '../../features/auth/services/secure_storage_service.dart';
import 'currency_formatter.dart';

class PdfReceiptGenerator {
  static const double _rollWidth = 58 * PdfPageFormat.mm;

  static Future<String> _resolveCashierName(String? cashierNama) async {
    if (cashierNama != null && cashierNama.trim().isNotEmpty) {
      return cashierNama.trim();
    }
    return 'Kasir';
  }

  static (double amount, double percentage) _resolveOrderServiceCharge(OrderModel order) {
    if (order.serviceChargeAmount > 0) {
      final rate = order.serviceChargePercentage > 0
          ? order.serviceChargePercentage
          : (order.subtotal > 0 ? ((order.serviceChargeAmount / order.subtotal) * 100).roundToDouble() : 0.0);
      return (order.serviceChargeAmount, rate);
    }
    if (order.serviceChargePercentage > 0) {
      final amt = (order.subtotal * (order.serviceChargePercentage / 100)).ceilToDouble();
      return (amt, order.serviceChargePercentage);
    }
    final diff = order.grandTotal - (order.subtotal + order.taxAmount);
    if (diff > 0 && order.subtotal > 0) {
      final rate = ((diff / order.subtotal) * 100).roundToDouble();
      return (diff, rate);
    }
    return (0.0, 0.0);
  }

  static (double amount, double percentage) _resolveTxServiceCharge(TransactionHeader tx) {
    if (tx.serviceChargeAmount > 0) {
      final rate = tx.serviceChargePercentage > 0
          ? tx.serviceChargePercentage
          : (tx.subtotal > 0 ? ((tx.serviceChargeAmount / tx.subtotal) * 100).roundToDouble() : 0.0);
      return (tx.serviceChargeAmount, rate);
    }
    if (tx.serviceChargePercentage > 0) {
      final amt = (tx.subtotal * (tx.serviceChargePercentage / 100)).ceilToDouble();
      return (amt, tx.serviceChargePercentage);
    }
    final diff = tx.grandTotal - (tx.subtotal + tx.taxAmount);
    if (diff > 0 && tx.subtotal > 0) {
      final rate = ((diff / tx.subtotal) * 100).roundToDouble();
      return (diff, rate);
    }
    return (0.0, 0.0);
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _getPackageComponents(List<String> productIds) async {
    if (productIds.isEmpty) return {};
    try {
      final db = await PosDatabase.instance.database;
      final placeholders = List.filled(productIds.length, '?').join(',');
      final rows = await db.rawQuery('''
        SELECT pi.package_id, pi.qty, p.nama as product_nama
        FROM package_items pi
        JOIN products p ON pi.product_id = p.id
        WHERE pi.package_id IN ($placeholders)
        ORDER BY pi.created_at ASC
      ''', productIds);

      final Map<String, List<Map<String, dynamic>>> result = {};
      for (var row in rows) {
        final pkgId = row['package_id'] as String;
        result.putIfAbsent(pkgId, () => []).add(row);
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static List<OrderItemModel> _consolidateOrderItems(
    List<OrderItemModel> items,
    Map<String, List<Map<String, dynamic>>> packageComponents,
  ) {
    final List<OrderItemModel> result = [];
    final Map<String, int> regularIndexMap = {};

    for (var item in items) {
      final isPkg = packageComponents.containsKey(item.produkId) && packageComponents[item.produkId]!.isNotEmpty;
      if (isPkg) {
        // Packages are NOT consolidated ("kecuali paket/beda paket")
        result.add(item);
      } else {
        final key = '${item.produkId}_${item.produkHarga}_${item.modifierSignature}';
        if (regularIndexMap.containsKey(key)) {
          final idx = regularIndexMap[key]!;
          final existing = result[idx];
          String? mergedNotes = existing.catatan;
          if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
            if (mergedNotes == null || mergedNotes.trim().isEmpty) {
              mergedNotes = item.catatan!.trim();
            } else if (!mergedNotes.contains(item.catatan!.trim())) {
              mergedNotes = '$mergedNotes, ${item.catatan!.trim()}';
            }
          }
          result[idx] = existing.copyWith(
            qty: existing.qty + item.qty,
            subtotal: existing.subtotal + item.subtotal,
            discountPercentage: existing.discountPercentage > 0 ? existing.discountPercentage : item.discountPercentage,
            discountAmount: existing.discountAmount + item.discountAmount,
            catatan: mergedNotes,
          );
        } else {
          regularIndexMap[key] = result.length;
          result.add(item);
        }
      }
    }
    return result;
  }

  static List<TransactionItem> _consolidateTransactionItems(
    List<TransactionItem> items,
    Map<String, List<Map<String, dynamic>>> packageComponents,
  ) {
    final List<TransactionItem> result = [];
    final Map<String, int> regularIndexMap = {};

    for (var item in items) {
      final isPkg = packageComponents.containsKey(item.produkId) && packageComponents[item.produkId]!.isNotEmpty;
      if (isPkg) {
        // Packages are NOT consolidated
        result.add(item);
      } else {
        final key = '${item.produkId}_${item.produkHarga}_${item.modifierSignature}';
        if (regularIndexMap.containsKey(key)) {
          final idx = regularIndexMap[key]!;
          final existing = result[idx];
          String? mergedNotes = existing.catatan;
          if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
            if (mergedNotes == null || mergedNotes.trim().isEmpty) {
              mergedNotes = item.catatan!.trim();
            } else if (!mergedNotes.contains(item.catatan!.trim())) {
              mergedNotes = '$mergedNotes, ${item.catatan!.trim()}';
            }
          }
          result[idx] = TransactionItem(
            id: existing.id,
            transactionId: existing.transactionId,
            produkId: existing.produkId,
            produkNama: existing.produkNama,
            produkHarga: existing.produkHarga,
            qty: existing.qty + item.qty,
            subtotal: existing.subtotal + item.subtotal,
            discountPercentage: existing.discountPercentage > 0 ? existing.discountPercentage : item.discountPercentage,
            discountAmount: existing.discountAmount + item.discountAmount,
            catatan: mergedNotes,
            selectedModifiers: existing.selectedModifiers,
          );
        } else {
          regularIndexMap[key] = result.length;
          result.add(item);
        }
      }
    }
    return result;
  }

  // --------------------------------------------------------------------------
  // 1. TAGIHAN SEMENTARA (Temporary Bill PDF)
  // --------------------------------------------------------------------------
  static Future<Uint8List> generateBillPdf({
    required OrderModel order,
    required List<OrderItemModel> items,
    String? cashierNama,
  }) async {
    final activeItems = items.where((i) => !i.isCancelled).toList();
    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final cashier = await _resolveCashierName(cashierNama ?? order.cashierNama);

    final productIds = activeItems.map((i) => i.produkId).toList();
    final packageComponents = await _getPackageComponents(productIds);
    final displayItems = _consolidateOrderItems(activeItems, packageComponents);

    final pdf = pw.Document();
    final font = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_rollWidth, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          final (scAmount, scRate) = _resolveOrderServiceCharge(order);
          final storeTotal = order.subtotal + scAmount + order.taxAmount - order.discountAmount;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Center(child: pw.Text('TAGIHAN', style: pw.TextStyle(font: fontBold, fontSize: 10))),
              pw.Center(child: pw.Text(storeName, style: pw.TextStyle(font: fontBold, fontSize: 10))),
              for (var line in storeAddress.split('\n'))
                pw.Center(child: pw.Text(line, style: pw.TextStyle(font: font, fontSize: 8))),
              if (storePhone.isNotEmpty)
                pw.Center(child: pw.Text('Telp: $storePhone', style: pw.TextStyle(font: font, fontSize: 8))),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              // Metadata
              pw.Text('Tgl   : $nowStr', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Kasir : $cashier', style: pw.TextStyle(font: font, fontSize: 8)),
              if (order.isTakeAway)
                pw.Text('Order : TAKE AWAY${order.onlinePlatform != null && order.onlinePlatform!.isNotEmpty ? " (${order.onlinePlatform})" : ""}', style: pw.TextStyle(font: fontBold, fontSize: 8))
              else if (order.tableNama != null && order.tableNama!.isNotEmpty)
                pw.Text('Meja  : ${order.tableNama}', style: pw.TextStyle(font: font, fontSize: 8)),
              if (order.customerName != null && order.customerName!.isNotEmpty)
                pw.Text('Nama  : ${order.customerName}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
              pw.Text('Status: BELUM DIBAYAR', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),

              // Items
              for (var item in displayItems) ...[
                _buildRowPdf(font, '${item.qty}x ${item.produkNama}', CurrencyFormatter.formatNumber(item.subtotal)),
                pw.Text('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (item.discountAmount > 0)
                  pw.Text('  (Disc -${item.discountPercentage > 0 ? '${item.discountPercentage.toStringAsFixed(0)}% ' : ''}${CurrencyFormatter.formatNumber(item.discountAmount)})', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (packageComponents.containsKey(item.produkId))
                  for (var comp in packageComponents[item.produkId]!)
                    pw.Text('   • ${(comp['qty'] as int) * item.qty}x ${comp['product_nama']}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (item.hasModifiers)
                  for (var m in item.selectedModifiers)
                    pw.Text('   + ${m.groupName}: ${m.optionName}${m.harga > 0 ? ' (+${CurrencyFormatter.formatNumber(m.harga)})' : ''}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (item.catatan != null && item.catatan!.trim().isNotEmpty)
                  pw.Text('     - ${item.catatan}', style: pw.TextStyle(font: font, fontSize: 8)),
              ],

              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),

              // Totals
              _buildRowPdf(font, 'Subtotal', CurrencyFormatter.formatNumber(order.subtotal)),
              if (order.discountAmount > 0)
                _buildRowPdf(
                  font,
                  'Diskon Nota${order.discountPercentage > 0 ? ' (${order.discountPercentage.toStringAsFixed(0)}%)' : ''}',
                  '-${CurrencyFormatter.formatNumber(order.discountAmount)}',
                ),
              if (scAmount > 0)
                _buildRowPdf(
                  font,
                  'Service (${scRate.toStringAsFixed(0)}%)',
                  CurrencyFormatter.formatNumber(scAmount),
                ),
              if (order.taxAmount > 0)
                _buildRowPdf(
                  font,
                  'Pajak (${order.taxPercentage.toStringAsFixed(0)}%)',
                  CurrencyFormatter.formatNumber(order.taxAmount),
                ),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              _buildRowPdf(
                fontBold,
                'TOTAL',
                CurrencyFormatter.formatNumber(order.onlinePlatformTotal != null && order.onlinePlatformTotal! > 0 ? storeTotal : order.grandTotal),
                isBold: true,
              ),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),

              if (order.onlinePlatformTotal != null && order.onlinePlatformTotal! > 0) ...[
                _buildRowPdf(
                  font,
                  'Komisi Online',
                  CurrencyFormatter.formatNumber(
                    ((order.platformDifference != null && order.platformDifference != 0)
                            ? order.platformDifference!
                            : (order.onlinePlatformTotal! - storeTotal))
                        .abs(),
                  ),
                ),
                _buildRowPdf(
                  fontBold,
                  order.onlinePlatform != null && order.onlinePlatform!.isNotEmpty
                      ? 'Total Aplikasi (${order.onlinePlatform})'
                      : 'Total Aplikasi',
                  CurrencyFormatter.formatNumber(order.onlinePlatformTotal!),
                  isBold: true,
                ),
                pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              ],
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              // Footer
              pw.Center(child: pw.Text('  * Ini BUKAN bukti pembayaran  ', style: pw.TextStyle(font: font, fontSize: 8))),
              pw.Center(child: pw.Text(' sah. Silakan bawa tagihan ini  ', style: pw.TextStyle(font: font, fontSize: 8))),
              pw.Center(child: pw.Text('        ke meja kasir.          ', style: pw.TextStyle(font: font, fontSize: 8))),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --------------------------------------------------------------------------
  // 2. STRUK PESANAN - DAPUR (Kitchen Order Ticket PDF)
  // --------------------------------------------------------------------------
  static Future<Uint8List> generateKitchenTicketPdf({
    required OrderModel order,
    required List<OrderItemModel> itemsToPrint,
    String? waveInfo,
    String? cashierNama,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.courier();
    final fontBold = pw.Font.courierBold();
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final cashier = await _resolveCashierName(cashierNama);
    final productIds = itemsToPrint.map((i) => i.produkId).toList();
    final packageComponents = await _getPackageComponents(productIds);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_rollWidth, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Center(child: pw.Text('PESANAN DAPUR', style: pw.TextStyle(font: fontBold, fontSize: 10))),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              pw.Text('No. Order : ${order.nomorOrder}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
              if (order.isTakeAway)
                pw.Text('Order     : TAKE AWAY${order.onlinePlatform != null && order.onlinePlatform!.trim().isNotEmpty ? " (${order.onlinePlatform!.trim()})" : ""}', style: pw.TextStyle(font: fontBold, fontSize: 8))
              else
                pw.Text('Meja      : ${order.tableNama ?? '-'}', style: pw.TextStyle(font: font, fontSize: 8)),
              if (order.customerName != null && order.customerName!.trim().isNotEmpty)
                pw.Text('Nama      : ${order.customerName!.trim()}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
              pw.Text('Batch : ${waveInfo ?? '#1 (Baru)'}', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Waktu     : $nowStr', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Kasir     : $cashier', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('QTY  ITEM', style: pw.TextStyle(font: fontBold, fontSize: 8)),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),

              for (var item in itemsToPrint) ...[
                pw.Text(
                  '${item.qty.toString().padLeft(2)}   ${item.produkNama}',
                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                ),
                if (packageComponents.containsKey(item.produkId))
                  for (var comp in packageComponents[item.produkId]!)
                    pw.Text('     • ${(comp['qty'] as int) * item.qty}x ${comp['product_nama']}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey800)),
                if (item.hasModifiers)
                  for (var m in item.selectedModifiers)
                    pw.Text('     + ${m.groupName}: ${m.optionName}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey800)),
                if (item.catatan != null && item.catatan!.trim().isNotEmpty)
                  pw.Text('     - ${item.catatan}', style: pw.TextStyle(font: font, fontSize: 8)),
              ],

              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --------------------------------------------------------------------------
  // 3. STRUK PEMBAYARAN (Customer Payment Receipt PDF)
  // --------------------------------------------------------------------------
  static Future<Uint8List> generateCashierReceiptPdf({
    required TransactionHeader transaction,
    required List<TransactionItem> items,
    String? tableName,
  }) async {
    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt);
    final cashier = await _resolveCashierName(transaction.cashierNama);

    final txProductIds = items.map((i) => i.produkId).toList();
    final txPackageComponents = await _getPackageComponents(txProductIds);
    final displayItems = _consolidateTransactionItems(items, txPackageComponents);

    final pdf = pw.Document();
    final font = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_rollWidth, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          final (txScAmount, txScRate) = _resolveTxServiceCharge(transaction);
          final storeTotal = transaction.subtotal + txScAmount + transaction.taxAmount;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(child: pw.Text(storeName, style: pw.TextStyle(font: fontBold, fontSize: 10))),
              for (var line in storeAddress.split('\n'))
                pw.Center(child: pw.Text(line, style: pw.TextStyle(font: font, fontSize: 8))),
              if (storePhone.isNotEmpty)
                pw.Center(child: pw.Text('Telp: $storePhone', style: pw.TextStyle(font: font, fontSize: 8))),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              pw.Text('Tgl   : $dateStr', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Kasir : $cashier', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('No.   : ${transaction.nomorTransaksi}', style: pw.TextStyle(font: font, fontSize: 8)),
              if (transaction.orderType == 'take_away')
                pw.Text('Order : TAKE AWAY${transaction.onlinePlatform != null && transaction.onlinePlatform!.isNotEmpty ? " (${transaction.onlinePlatform})" : ""}', style: pw.TextStyle(font: fontBold, fontSize: 8))
              else if (tableName != null && tableName.isNotEmpty)
                pw.Text('Meja  : $tableName', style: pw.TextStyle(font: font, fontSize: 8)),
              if (transaction.customerName != null && transaction.customerName!.isNotEmpty)
                pw.Text('Nama  : ${transaction.customerName}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),

              for (var item in displayItems) ...[
                _buildRowPdf(font, '${item.qty}x ${item.produkNama}', CurrencyFormatter.formatNumber(item.subtotal)),
                pw.Text('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (item.discountAmount > 0)
                  pw.Text('  (Disc -${item.discountPercentage > 0 ? '${item.discountPercentage.toStringAsFixed(0)}% ' : ''}${CurrencyFormatter.formatNumber(item.discountAmount)})', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (txPackageComponents.containsKey(item.produkId))
                  for (var comp in txPackageComponents[item.produkId]!)
                    pw.Text('   • ${(comp['qty'] as int) * item.qty}x ${comp['product_nama']}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (item.hasModifiers)
                  for (var m in item.selectedModifiers)
                    pw.Text('   + ${m.groupName}: ${m.optionName}${m.harga > 0 ? ' (+${CurrencyFormatter.formatNumber(m.harga)})' : ''}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                if (item.catatan != null && item.catatan!.trim().isNotEmpty)
                  pw.Text('     - ${item.catatan}', style: pw.TextStyle(font: font, fontSize: 8)),
              ],

              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),

              _buildRowPdf(font, 'Subtotal', CurrencyFormatter.formatNumber(transaction.subtotal)),
              if (transaction.discountAmount > 0)
                _buildRowPdf(
                  font,
                  'Diskon Nota${transaction.discountPercentage > 0 ? ' (${transaction.discountPercentage.toStringAsFixed(0)}%)' : ''}',
                  '-${CurrencyFormatter.formatNumber(transaction.discountAmount)}',
                ),
              if (txScAmount > 0)
                _buildRowPdf(
                  font,
                  'Service (${txScRate.toStringAsFixed(0)}%)',
                  CurrencyFormatter.formatNumber(txScAmount),
                ),
              if (transaction.taxAmount > 0)
                _buildRowPdf(
                  font,
                  'Pajak (${transaction.taxPercentage.toStringAsFixed(0)}%)',
                  CurrencyFormatter.formatNumber(transaction.taxAmount),
                ),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              _buildRowPdf(
                fontBold,
                'TOTAL',
                CurrencyFormatter.formatNumber(transaction.onlinePlatformTotal != null ? storeTotal : transaction.grandTotal),
                isBold: true,
              ),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              if (transaction.onlinePlatformTotal != null && transaction.onlinePlatformTotal! > 0) ...[
                _buildRowPdf(
                  font,
                  'Komisi Online',
                  CurrencyFormatter.formatNumber(
                    ((transaction.platformDifference != null && transaction.platformDifference != 0)
                            ? transaction.platformDifference!
                            : (transaction.onlinePlatformTotal! - (transaction.subtotal + transaction.taxAmount)))
                        .abs(),
                  ),
                ),
                _buildRowPdf(
                  fontBold,
                  transaction.onlinePlatform != null && transaction.onlinePlatform!.isNotEmpty
                      ? 'Total Aplikasi (${transaction.onlinePlatform})'
                      : 'Total Aplikasi',
                  CurrencyFormatter.formatNumber(transaction.onlinePlatformTotal!),
                  isBold: true,
                ),
                pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              ],

              _buildRowPdf(
                font,
                transaction.paymentMethodNama.isEmpty ? 'Tunai' : transaction.paymentMethodNama,
                CurrencyFormatter.formatNumber(transaction.nominalBayar),
              ),
              _buildRowPdf(
                font,
                'Kembalian',
                CurrencyFormatter.formatNumber(transaction.kembalian),
              ),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              pw.Center(child: pw.Text('Terima Kasih Atas', style: pw.TextStyle(font: font, fontSize: 8))),
              pw.Center(child: pw.Text('Kunjungan Anda!', style: pw.TextStyle(font: font, fontSize: 8))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --------------------------------------------------------------------------
  // 4. REKAPITULASI KASIR / TUTUP SHIFT KASIR (Closing Shift PDF)
  // --------------------------------------------------------------------------
  static Future<Uint8List> generateReportPdf({
    required String dateStr,
    required double totalSales,
    required int totalTransactions,
    required double totalTax,
    double? totalServiceCharge,
    required Map<String, double> paymentBreakdown,
    required List<Map<String, dynamic>> topProducts,
    String? cashierNama,
    String? startTimeStr,
    String? endTimeStr,
    int? totalItemsCount,
    double? expectedCash,
    double? actualCash,
    double? selisihCash,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    final String cashier = await _resolveCashierName(cashierNama);
    final String nowFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final String start = startTimeStr ?? '$dateStr 08:00';
    final String end = endTimeStr ?? nowFormatted;
    final int itemsCount = totalItemsCount ?? topProducts.fold<int>(0, (sum, p) => sum + ((p['qty'] as num?)?.toInt() ?? 0));

    final double expCash = expectedCash ?? (paymentBreakdown['Tunai'] ?? totalSales);
    final double actCash = actualCash ?? expCash;
    final double diffCash = selisihCash ?? (actCash - expCash);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_rollWidth, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Center(child: pw.Text('TUTUP SHIFT KASIR', style: pw.TextStyle(font: fontBold, fontSize: 10))),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              pw.Text('Kasir   : $cashier', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Mulai   : $start', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Selesai : $end', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),

              pw.Center(child: pw.Text('RINCIAN PENDAPATAN', style: pw.TextStyle(font: fontBold, fontSize: 9))),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Total Transaksi : $totalTransactions', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Total Item      : $itemsCount', style: pw.TextStyle(font: font, fontSize: 8)),
              if (totalServiceCharge != null && totalServiceCharge > 0)
                _buildRowPdf(font, 'Total Service', CurrencyFormatter.formatNumber(totalServiceCharge)),
              if (totalTax > 0)
                _buildRowPdf(font, 'Total Pajak', CurrencyFormatter.formatNumber(totalTax)),
              pw.SizedBox(height: 4),

              for (var entry in paymentBreakdown.entries)
                if (entry.value >= 0)
                  _buildRowPdf(font, entry.key, CurrencyFormatter.formatNumber(entry.value)),

              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              _buildRowPdf(
                fontBold,
                'TOTAL OMZET',
                CurrencyFormatter.formatNumber(totalSales),
                isBold: true,
              ),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              if (topProducts.isNotEmpty) ...[
                pw.Center(child: pw.Text('5 PRODUK TERLARIS', style: pw.TextStyle(font: fontBold, fontSize: 9))),
                pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
                for (var p in topProducts.take(5))
                  _buildRowPdf(
                    font,
                    (p['nama'] ?? p['name'] ?? p['produk_nama'] ?? 'Produk').toString(),
                    '${p['qty'] ?? 0}x',
                  ),
                pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),
              ],

              pw.Center(child: pw.Text('PENCOCOKAN KAS FISIK (TUNAI)', style: pw.TextStyle(font: fontBold, fontSize: 9))),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              _buildRowPdf(font, 'Sistem (Expected)', CurrencyFormatter.formatNumber(expCash)),
              _buildRowPdf(font, 'Laci Kas (Actual)', CurrencyFormatter.formatNumber(actCash)),
              pw.Text('--------------------------------', style: pw.TextStyle(font: font, fontSize: 8)),
              _buildRowPdf(fontBold, 'SELISIH', CurrencyFormatter.formatNumber(diffCash), isBold: true),
              pw.Text('================================', style: pw.TextStyle(font: font, fontSize: 8)),

              pw.Center(child: pw.Text('Validasi Sistem POS', style: pw.TextStyle(font: font, fontSize: 8))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRowPdf(
    pw.Font font,
    String left,
    String right, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(left, style: pw.TextStyle(font: isBold ? pw.Font.courierBold() : font, fontSize: 8)),
        pw.Text(right, style: pw.TextStyle(font: isBold ? pw.Font.courierBold() : font, fontSize: 8)),
      ],
    );
  }
}
