import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../features/pos/domain/models/order.dart';
import '../../features/pos/domain/models/order_item.dart';
import '../../features/pos/domain/models/transaction.dart';
import '../../features/auth/services/secure_storage_service.dart';
import 'currency_formatter.dart';

class ReceiptGenerator {
  static CapabilityProfile? _cachedProfile;

  static Future<CapabilityProfile> _getProfile() async {
    _cachedProfile ??= await CapabilityProfile.load();
    return _cachedProfile!;
  }

  // Generate 58mm ESC/POS bytes for Kitchen Order Ticket (KOT)
  static Future<List<int>> generateKitchenTicket({
    required OrderModel order,
    required List<OrderItemModel> itemsToPrint,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('*** TIKET DAPUR ***');
    bytes += generator.text('================================');
    
    // Meja Info (Bold & Large)
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.text(order.tableNama ?? 'MEJA');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text('No. Order: ${order.nomorOrder}');
    bytes += generator.text('Waktu: ${DateTime.now().toString().split('.').first}');
    bytes += generator.text('================================');
    
    // Items
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    for (var item in itemsToPrint) {
      bytes += generator.text('${item.qty}x ${item.produkNama}', styles: const PosStyles(bold: true));
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('  * Catatan: ${item.catatan}');
      }
    }
    
    bytes += generator.text('================================');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // Generate 58mm ESC/POS bytes for Cashier receipt
  static Future<List<int>> generateCashierReceipt({
    required TransactionHeader transaction,
    required List<TransactionItem> items,
    String? tableName,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KASIR POS OFFLINE';
    final storeAddress = await storage.getStoreAddress() ?? 'SaaS Offline POS';
    final storePhone = await storage.getStorePhone();

    // Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(storeName);
    bytes += generator.text(storeAddress);
    if (storePhone != null && storePhone.isNotEmpty) {
      bytes += generator.text('Telp: $storePhone');
    }
    bytes += generator.text('================================');
    
    // Meta Info
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('No. Trans: ${transaction.nomorTransaksi}');
    bytes += generator.text('Waktu: ${transaction.createdAt}');
    if (tableName != null && tableName.isNotEmpty) {
      bytes += generator.text('Meja: $tableName');
    }
    bytes += generator.text('Kasir: ${transaction.cashierNama ?? 'Pemilik'}');
    bytes += generator.text('Metode: ${transaction.paymentMethodNama}');
    bytes += generator.text('================================');

    // Items List
    for (var item in items) {
      bytes += generator.text(item.produkNama);
      // Row formatting for Qty x Price and Subtotal
      final qtyPrice = '  ${item.qty}x ${CurrencyFormatter.format(item.produkHarga)}';
      final subtotal = CurrencyFormatter.format(item.subtotal);
      final spaceCount = 32 - qtyPrice.length - subtotal.length;
      final spaces = spaceCount > 0 ? ' ' * spaceCount : ' ';
      bytes += generator.text('$qtyPrice$spaces$subtotal');
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('  * Catatan: ${item.catatan}');
      }
    }

    bytes += generator.text('================================');

    // Summary Totals
    bytes += _renderSummaryRow(generator, 'Subtotal:', CurrencyFormatter.format(transaction.subtotal));
    if (transaction.taxAmount > 0) {
      bytes += _renderSummaryRow(
        generator, 
        'PPN (${transaction.taxPercentage}%):', 
        CurrencyFormatter.format(transaction.taxAmount)
      );
    }
    bytes += _renderSummaryRow(generator, 'Grand Total:', CurrencyFormatter.format(transaction.grandTotal), bold: true);
    bytes += _renderSummaryRow(generator, 'Bayar:', CurrencyFormatter.format(transaction.nominalBayar));
    bytes += _renderSummaryRow(generator, 'Kembalian:', CurrencyFormatter.format(transaction.kembalian));

    bytes += generator.text('================================');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text('Terima Kasih');
    bytes += generator.text('Atas Kunjungan Anda');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // Generate 58mm ESC/POS bytes for Bill / Tagihan Sementara
  static Future<List<int>> generateBillReceipt({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KASIR POS OFFLINE';
    final storeAddress = await storage.getStoreAddress() ?? 'SaaS Offline POS';
    final storePhone = await storage.getStorePhone();

    // Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('*** TAGIHAN SEMENTARA ***');
    bytes += generator.text(storeName);
    bytes += generator.text(storeAddress);
    if (storePhone != null && storePhone.isNotEmpty) {
      bytes += generator.text('Telp: $storePhone');
    }
    bytes += generator.text('================================');
    
    // Meta Info
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('No. Order: ${order.nomorOrder}');
    bytes += generator.text('Waktu: ${DateTime.now().toString().split('.').first}');
    if (order.tableNama != null && order.tableNama!.isNotEmpty) {
      bytes += generator.text('Meja: ${order.tableNama}');
    }
    bytes += generator.text('================================');

    // Items List
    for (var item in items) {
      bytes += generator.text(item.produkNama);
      final qtyPrice = '  ${item.qty}x ${CurrencyFormatter.format(item.produkHarga)}';
      final subtotal = CurrencyFormatter.format(item.subtotal);
      final spaceCount = 32 - qtyPrice.length - subtotal.length;
      final spaces = spaceCount > 0 ? ' ' * spaceCount : ' ';
      bytes += generator.text('$qtyPrice$spaces$subtotal');
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('  * Catatan: ${item.catatan}');
      }
    }

    bytes += generator.text('================================');

    // Summary Totals
    bytes += _renderSummaryRow(generator, 'Subtotal:', CurrencyFormatter.format(order.subtotal));
    if (order.taxAmount > 0) {
      bytes += _renderSummaryRow(
        generator, 
        'PPN (${order.taxPercentage}%):', 
        CurrencyFormatter.format(order.taxAmount)
      );
    }
    bytes += _renderSummaryRow(generator, 'Grand Total:', CurrencyFormatter.format(order.grandTotal), bold: true);

    bytes += generator.text('================================');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text('Bukan Bukti Pembayaran Resmi');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }


  // Generate 58mm ESC/POS bytes for Sales Report
  static Future<List<int>> generateReportReceipt({
    required String dateStr,
    required double totalSales,
    required int totalTransactions,
    required double totalTax,
    required Map<String, double> paymentBreakdown,
    required List<Map<String, dynamic>> topProducts,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('LAPORAN RINGKASAN HARIAN');
    bytes += generator.text('POS OFFLINE SAAS');
    bytes += generator.text('================================');

    // Meta Info
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('Tanggal: $dateStr');
    bytes += generator.text('Tercetak: ${DateTime.now().toString().split('.').first}');
    bytes += generator.text('================================');

    // Main Stats
    bytes += _renderSummaryRow(generator, 'Total Transaksi:', '$totalTransactions');
    bytes += _renderSummaryRow(generator, 'Total PPN:', CurrencyFormatter.format(totalTax));
    bytes += _renderSummaryRow(generator, 'Omset Kotor:', CurrencyFormatter.format(totalSales), bold: true);
    bytes += generator.text('--------------------------------');

    // Payment Methods Breakdown
    bytes += generator.text('Metode Pembayaran:', styles: const PosStyles(bold: true));
    paymentBreakdown.forEach((method, total) {
      if (total > 0) {
        bytes += _renderSummaryRow(generator, ' - $method:', CurrencyFormatter.format(total));
      }
    });
    bytes += generator.text('--------------------------------');

    // Top Products
    bytes += generator.text('Produk Terlaris:', styles: const PosStyles(bold: true));
    for (var prod in topProducts) {
      final name = prod['nama'] as String;
      final qty = prod['qty'] as int;
      final total = prod['total'] as double;
      bytes += generator.text('$name');
      bytes += _renderSummaryRow(generator, '   Qty: $qty', CurrencyFormatter.format(total));
    }

    bytes += generator.text('================================');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  static List<int> _renderSummaryRow(
    Generator generator,
    String label,
    String value, {
    bool bold = false,
  }) {
    final spaceCount = 32 - label.length - value.length;
    final spaces = spaceCount > 0 ? ' ' * spaceCount : ' ';
    return generator.text('$label$spaces$value', styles: PosStyles(bold: bold));
  }
}
