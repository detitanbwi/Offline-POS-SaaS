import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
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

  // --------------------------------------------------------------------------
  // 1. TAGIHAN SEMENTARA (Temporary Bill)
  // --------------------------------------------------------------------------
  static Future<List<int>> generateBillReceipt({
    required OrderModel order,
    required List<OrderItemModel> items,
    String? cashierNama,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Title & Store Info Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Tagihan Sementara');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text(storeName, styles: const PosStyles(bold: true));
    for (var line in storeAddress.split('\n')) {
      bytes += generator.text(line);
    }
    if (storePhone.isNotEmpty) {
      bytes += generator.text('Telp: $storePhone');
    }
    bytes += generator.text('================================');

    // Metadata
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('Tgl   : $nowStr');
    bytes += generator.text('Kasir : ${cashierNama ?? 'Bima'}');
    if (order.tableNama != null && order.tableNama!.isNotEmpty) {
      bytes += generator.text('Meja  : ${order.tableNama}');
    }
    bytes += generator.text('Status: BELUM DIBAYAR');
    bytes += generator.text('--------------------------------');

    // Items Listing
    for (var item in items) {
      bytes += generator.text('${item.qty}x ${item.produkNama}');
      final unitPrice = CurrencyFormatter.formatNumber(item.produkHarga);
      final subtotal = CurrencyFormatter.formatNumber(item.subtotal);
      final qtyPrice = '  @ $unitPrice';
      bytes += _renderRow(generator, qtyPrice, subtotal);

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('     - ${item.catatan}');
      }
    }

    bytes += generator.text('--------------------------------');

    // Totals Summary
    bytes += _renderRow(
      generator,
      'Subtotal',
      CurrencyFormatter.formatNumber(order.subtotal),
    );
    if (order.taxAmount > 0) {
      bytes += _renderRow(
        generator,
        'Pajak (${order.taxPercentage.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(order.taxAmount),
      );
    }
    bytes += generator.text('--------------------------------');
    bytes += _renderRow(
      generator,
      'TOTAL TAGIHAN',
      CurrencyFormatter.formatNumber(order.grandTotal),
      bold: true,
    );
    bytes += generator.text('================================');

    // Warning Footer
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text('  * Ini BUKAN bukti pembayaran  ');
    bytes += generator.text(' sah. Silakan bawa tagihan ini  ');
    bytes += generator.text('        ke meja kasir.          ');
    bytes += generator.text('================================');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // --------------------------------------------------------------------------
  // 2. STRUK PESANAN - DAPUR (Kitchen Order Ticket)
  // --------------------------------------------------------------------------
  static Future<List<int>> generateKitchenTicket({
    required OrderModel order,
    required List<OrderItemModel> itemsToPrint,
    String? waveInfo,
    String? cashierNama,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Banner Header
    bytes += generator.text('================================');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('PESANAN DAPUR');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('================================');

    // Metadata
    bytes += generator.text('Meja      : ${order.tableNama ?? '04'}');
    bytes += generator.text('Gelombang : ${waveInfo ?? '#1 (Baru)'}');
    bytes += generator.text('Waktu     : $nowStr');
    bytes += generator.text('Kasir     : ${cashierNama ?? 'Bima'}');
    bytes += generator.text('--------------------------------');
    bytes += generator.text('QTY  ITEM', styles: const PosStyles(bold: true));
    bytes += generator.text('--------------------------------');

    // Items List
    for (var item in itemsToPrint) {
      final qtyStr = item.qty.toString().padRight(4);
      bytes += generator.text('$qtyStr ${item.produkNama}', styles: const PosStyles(bold: true));
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('     - ${item.catatan}');
      }
    }

    bytes += generator.text('================================');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // --------------------------------------------------------------------------
  // 3. STRUK PEMBAYARAN (Customer Payment Receipt)
  // --------------------------------------------------------------------------
  static Future<List<int>> generateCashierReceipt({
    required TransactionHeader transaction,
    required List<TransactionItem> items,
    String? tableName,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt);

    // Store Info Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(storeName);
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    for (var line in storeAddress.split('\n')) {
      bytes += generator.text(line);
    }
    if (storePhone.isNotEmpty) {
      bytes += generator.text('Telp: $storePhone');
    }
    bytes += generator.text('================================');

    // Metadata
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('Tgl   : $dateStr');
    bytes += generator.text('Kasir : ${transaction.cashierNama ?? 'Bima'}');
    bytes += generator.text('No.   : ${transaction.nomorTransaksi}');
    if (tableName != null && tableName.isNotEmpty) {
      bytes += generator.text('Meja  : $tableName');
    }
    bytes += generator.text('--------------------------------');

    // Items List
    for (var item in items) {
      bytes += generator.text('${item.qty}x ${item.produkNama}');
      final unitPrice = CurrencyFormatter.formatNumber(item.produkHarga);
      final subtotal = CurrencyFormatter.formatNumber(item.subtotal);
      final qtyPrice = '  @ $unitPrice';
      bytes += _renderRow(generator, qtyPrice, subtotal);

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('     - ${item.catatan}');
      }
    }

    bytes += generator.text('--------------------------------');

    // Summary Totals
    bytes += _renderRow(
      generator,
      'Subtotal',
      CurrencyFormatter.formatNumber(transaction.subtotal),
    );
    if (transaction.taxAmount > 0) {
      bytes += _renderRow(
        generator,
        'Pajak (${transaction.taxPercentage.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(transaction.taxAmount),
      );
    }
    bytes += generator.text('--------------------------------');
    bytes += _renderRow(
      generator,
      'TOTAL',
      CurrencyFormatter.formatNumber(transaction.grandTotal),
      bold: true,
    );
    bytes += generator.text('================================');

    // Payment & Change
    bytes += _renderRow(
      generator,
      transaction.paymentMethodNama.isEmpty ? 'Tunai' : transaction.paymentMethodNama,
      CurrencyFormatter.formatNumber(transaction.nominalBayar),
    );
    bytes += _renderRow(
      generator,
      'Kembalian',
      CurrencyFormatter.formatNumber(transaction.kembalian),
    );
    bytes += generator.text('================================');

    // Footer
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text('       Terima Kasih Atas ');
    bytes += generator.text('        Kunjungan Anda!');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // --------------------------------------------------------------------------
  // 4. REKAPITULASI KASIR / TUTUP SHIFT KASIR (Cashier Shift Closing Report)
  // --------------------------------------------------------------------------
  static Future<List<int>> generateReportReceipt({
    required String dateStr,
    required double totalSales,
    required int totalTransactions,
    required double totalTax,
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
    final profile = await _getProfile();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final String cashier = cashierNama ?? 'Bima';
    final String start = startTimeStr ?? '$dateStr 08:00';
    final String end = endTimeStr ?? '$dateStr 15:00';
    final int itemsCount = totalItemsCount ?? topProducts.fold<int>(0, (sum, p) => sum + ((p['qty'] as num?)?.toInt() ?? 0));

    // Shift Header Banner
    bytes += generator.text('================================');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('TUTUP SHIFT KASIR');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('================================');

    // Metadata
    bytes += generator.text('Kasir   : $cashier');
    bytes += generator.text('Mulai   : $start');
    bytes += generator.text('Selesai : $end');
    bytes += generator.text('--------------------------------');

    // Revenue Breakdown Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('RINCIAN PENDAPATAN');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('--------------------------------');
    bytes += generator.text('Total Transaksi : $totalTransactions');
    bytes += generator.text('Total Item      : $itemsCount');
    bytes += generator.text('');

    // Payment Methods Breakdown
    paymentBreakdown.forEach((method, total) {
      if (total >= 0) {
        bytes += _renderRow(generator, method, CurrencyFormatter.formatNumber(total));
      }
    });

    bytes += generator.text('--------------------------------');
    bytes += _renderRow(
      generator,
      'TOTAL OMZET',
      CurrencyFormatter.formatNumber(totalSales),
      bold: true,
    );
    bytes += generator.text('================================');

    // Physical Cash Reconciliation Banner
    final double expCash = expectedCash ?? (paymentBreakdown['Tunai'] ?? totalSales);
    final double actCash = actualCash ?? expCash;
    final double diffCash = selisihCash ?? (actCash - expCash);

    bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('  PENCOCOKAN KAS FISIK (TUNAI)  ');
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('--------------------------------');
    bytes += _renderRow(generator, 'Sistem (Expected)', CurrencyFormatter.formatNumber(expCash));
    bytes += _renderRow(generator, 'Laci Kas (Actual)', CurrencyFormatter.formatNumber(actCash));
    bytes += generator.text('--------------------------------');
    bytes += _renderRow(generator, 'SELISIH', CurrencyFormatter.formatNumber(diffCash), bold: true);
    bytes += generator.text('================================');

    // Footer
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text('      Validasi Sistem POS       ');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // Helper method to format left-aligned label and right-aligned value in 32-character line
  static List<int> _renderRow(
    Generator generator,
    String left,
    String right, {
    bool bold = false,
  }) {
    const int totalWidth = 32;
    final spaceCount = totalWidth - left.length - right.length;
    if (spaceCount > 0) {
      final line = '$left${' ' * spaceCount}$right';
      return generator.text(line, styles: PosStyles(bold: bold));
    } else {
      // If overflowing 32 chars, print left then right on next line
      List<int> rBytes = generator.text(left, styles: PosStyles(bold: bold));
      final rightSpaces = totalWidth - right.length;
      final rightLine = '${' ' * (rightSpaces > 0 ? rightSpaces : 0)}$right';
      rBytes += generator.text(rightLine, styles: PosStyles(bold: bold));
      return rBytes;
    }
  }

  // --------------------------------------------------------------------------
  // TEXT PREVIEW HELPERS (For 58mm Thermal Simulation Screen View)
  // --------------------------------------------------------------------------
  static String formatTextRow(String left, String right, {int width = 32}) {
    final spaces = width - left.length - right.length;
    if (spaces > 0) {
      return '$left${' ' * spaces}$right';
    }
    return '$left\n${' ' * (width - right.length > 0 ? width - right.length : 0)}$right';
  }

  static String centerText(String text, {int width = 32}) {
    if (text.length >= width) return text;
    final leftPadding = (width - text.length) ~/ 2;
    return '${' ' * leftPadding}$text';
  }

  static Future<String> formatBillTextPreview({
    required OrderModel order,
    required List<OrderItemModel> items,
    String? cashierNama,
  }) async {
    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln(centerText('Tagihan Sementara'));
    buffer.writeln(centerText(storeName));
    for (var line in storeAddress.split('\n')) {
      buffer.writeln(centerText(line));
    }
    if (storePhone.isNotEmpty) {
      buffer.writeln(centerText('Telp: $storePhone'));
    }
    buffer.writeln('================================');
    buffer.writeln('Tgl   : $nowStr');
    buffer.writeln('Kasir : ${cashierNama ?? 'Bima'}');
    if (order.tableNama != null && order.tableNama!.isNotEmpty) {
      buffer.writeln('Meja  : ${order.tableNama}');
    }
    buffer.writeln('Status: BELUM DIBAYAR');
    buffer.writeln('--------------------------------');
    for (var item in items) {
      buffer.writeln('${item.qty}x ${item.produkNama}');
      buffer.writeln(formatTextRow('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', CurrencyFormatter.formatNumber(item.subtotal)));
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        buffer.writeln('     - ${item.catatan}');
      }
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(formatTextRow('Subtotal', CurrencyFormatter.formatNumber(order.subtotal)));
    if (order.taxAmount > 0) {
      buffer.writeln(formatTextRow('Pajak (${order.taxPercentage.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(order.taxAmount)));
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(formatTextRow('TOTAL TAGIHAN', CurrencyFormatter.formatNumber(order.grandTotal)));
    buffer.writeln('================================');
    buffer.writeln('  * Ini BUKAN bukti pembayaran  ');
    buffer.writeln(' sah. Silakan bawa tagihan ini  ');
    buffer.writeln('        ke meja kasir.          ');
    buffer.writeln('================================');
    return buffer.toString();
  }

  static Future<String> formatKitchenTextPreview({
    required OrderModel order,
    required List<OrderItemModel> itemsToPrint,
    String? waveInfo,
    String? cashierNama,
  }) async {
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln(centerText('PESANAN DAPUR'));
    buffer.writeln('================================');
    buffer.writeln('Meja      : ${order.tableNama ?? '04'}');
    buffer.writeln('Gelombang : ${waveInfo ?? '#1 (Baru)'}');
    buffer.writeln('Waktu     : $nowStr');
    buffer.writeln('Kasir     : ${cashierNama ?? 'Bima'}');
    buffer.writeln('--------------------------------');
    buffer.writeln('QTY  ITEM');
    buffer.writeln('--------------------------------');
    for (var item in itemsToPrint) {
      final qtyStr = item.qty.toString().padRight(4);
      buffer.writeln('$qtyStr ${item.produkNama}');
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        buffer.writeln('     - ${item.catatan}');
      }
    }
    buffer.writeln('================================');
    return buffer.toString();
  }

  static Future<String> formatCashierTextPreview({
    required TransactionHeader transaction,
    required List<TransactionItem> items,
    String? tableName,
  }) async {
    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt);

    final buffer = StringBuffer();
    buffer.writeln(centerText(storeName));
    for (var line in storeAddress.split('\n')) {
      buffer.writeln(centerText(line));
    }
    if (storePhone.isNotEmpty) {
      buffer.writeln(centerText('Telp: $storePhone'));
    }
    buffer.writeln('================================');
    buffer.writeln('Tgl   : $dateStr');
    buffer.writeln('Kasir : ${transaction.cashierNama ?? 'Bima'}');
    buffer.writeln('No.   : ${transaction.nomorTransaksi}');
    if (tableName != null && tableName.isNotEmpty) {
      buffer.writeln('Meja  : $tableName');
    }
    buffer.writeln('--------------------------------');
    for (var item in items) {
      buffer.writeln('${item.qty}x ${item.produkNama}');
      buffer.writeln(formatTextRow('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', CurrencyFormatter.formatNumber(item.subtotal)));
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        buffer.writeln('     - ${item.catatan}');
      }
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(formatTextRow('Subtotal', CurrencyFormatter.formatNumber(transaction.subtotal)));
    if (transaction.taxAmount > 0) {
      buffer.writeln(formatTextRow('Pajak (${transaction.taxPercentage.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(transaction.taxAmount)));
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(formatTextRow('TOTAL', CurrencyFormatter.formatNumber(transaction.grandTotal)));
    buffer.writeln('================================');
    buffer.writeln(formatTextRow(transaction.paymentMethodNama.isEmpty ? 'Tunai' : transaction.paymentMethodNama, CurrencyFormatter.formatNumber(transaction.nominalBayar)));
    buffer.writeln(formatTextRow('Kembalian', CurrencyFormatter.formatNumber(transaction.kembalian)));
    buffer.writeln('================================');
    buffer.writeln(centerText('Terima Kasih Atas'));
    buffer.writeln(centerText('Kunjungan Anda!'));
    return buffer.toString();
  }

  static Future<String> formatReportTextPreview({
    required String dateStr,
    required double totalSales,
    required int totalTransactions,
    required double totalTax,
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
    final String cashier = cashierNama ?? 'Bima';
    final String start = startTimeStr ?? '$dateStr 08:00';
    final String end = endTimeStr ?? '$dateStr 15:00';
    final int itemsCount = totalItemsCount ?? topProducts.fold<int>(0, (sum, p) => sum + ((p['qty'] as num?)?.toInt() ?? 0));

    final double expCash = expectedCash ?? (paymentBreakdown['Tunai'] ?? totalSales);
    final double actCash = actualCash ?? expCash;
    final double diffCash = selisihCash ?? (actCash - expCash);

    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln(centerText('TUTUP SHIFT KASIR'));
    buffer.writeln('================================');
    buffer.writeln('Kasir   : $cashier');
    buffer.writeln('Mulai   : $start');
    buffer.writeln('Selesai : $end');
    buffer.writeln('--------------------------------');
    buffer.writeln(centerText('RINCIAN PENDAPATAN'));
    buffer.writeln('--------------------------------');
    buffer.writeln('Total Transaksi : $totalTransactions');
    buffer.writeln('Total Item      : $itemsCount');
    buffer.writeln('');
    paymentBreakdown.forEach((method, total) {
      if (total >= 0) {
        buffer.writeln(formatTextRow(method, CurrencyFormatter.formatNumber(total)));
      }
    });
    buffer.writeln('--------------------------------');
    buffer.writeln(formatTextRow('TOTAL OMZET', CurrencyFormatter.formatNumber(totalSales)));
    buffer.writeln('================================');
    buffer.writeln(centerText('PENCOCOKAN KAS FISIK (TUNAI)'));
    buffer.writeln('--------------------------------');
    buffer.writeln(formatTextRow('Sistem (Expected)', CurrencyFormatter.formatNumber(expCash)));
    buffer.writeln(formatTextRow('Laci Kas (Actual)', CurrencyFormatter.formatNumber(actCash)));
    buffer.writeln('--------------------------------');
    buffer.writeln(formatTextRow('SELISIH', CurrencyFormatter.formatNumber(diffCash)));
    buffer.writeln('================================');
    buffer.writeln(centerText('Validasi Sistem POS'));
    return buffer.toString();
  }
}

