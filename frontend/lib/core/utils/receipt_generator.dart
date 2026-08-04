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

  static Future<String> _resolveCashierName(String? cashierNama) async {
    if (cashierNama != null && cashierNama.trim().isNotEmpty) {
      return cashierNama.trim();
    }
    final storage = SecureStorageService();
    final owner = await storage.getOwnerUsername();
    if (owner != null && owner.trim().isNotEmpty) {
      return owner.trim();
    }
    return 'Kasir';
  }

  static String _equalsDivider(int width) => '=' * width;
  static String _dashDivider(int width) => '-' * width;

  // --------------------------------------------------------------------------
  // 1. TAGIHAN SEMENTARA (Temporary Bill)
  // --------------------------------------------------------------------------
  static Future<List<int>> generateBillReceipt({
    required OrderModel order,
    required List<OrderItemModel> items,
    String? cashierNama,
    PaperSize paperSize = PaperSize.mm58,
    int charsPerLine = 32,
    bool autoCut = false,
  }) async {
    final activeItems = items.where((i) => !i.isCancelled).toList();
    final profile = await _getProfile();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final cashier = await _resolveCashierName(cashierNama);

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    // Title & Store Info Header
    bytes += generator.text('TAGIHAN', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(storeName, styles: const PosStyles(align: PosAlign.center, bold: true));
    for (var line in storeAddress.split('\n')) {
      bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
    }
    if (storePhone.isNotEmpty) {
      bytes += generator.text('Telp: $storePhone', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Metadata
    bytes += generator.text('Tgl   : $nowStr', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Kasir : $cashier', styles: const PosStyles(align: PosAlign.left));
    if (order.isTakeAway) {
      bytes += generator.text('Order : TAKE AWAY', styles: const PosStyles(align: PosAlign.left, bold: true));
    } else if (order.tableNama != null && order.tableNama!.isNotEmpty) {
      bytes += generator.text('Meja  : ${order.tableNama}', styles: const PosStyles(align: PosAlign.left));
    }
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bytes += generator.text('Nama  : ${order.customerName}', styles: const PosStyles(align: PosAlign.left, bold: true));
    }
    bytes += generator.text('Status: BELUM DIBAYAR', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    // Items Listing
    for (var item in activeItems) {
      bytes += generator.text('${item.qty}x ${item.produkNama}', styles: const PosStyles(align: PosAlign.left));
      final unitPrice = CurrencyFormatter.formatNumber(item.produkHarga);
      final subtotal = CurrencyFormatter.formatNumber(item.subtotal);
      final qtyPrice = '  @ $unitPrice';
      bytes += _renderRow(generator, qtyPrice, subtotal, totalWidth: charsPerLine);

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('     - ${item.catatan}', styles: const PosStyles(align: PosAlign.left));
      }
    }

    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    // Totals Summary
    bytes += _renderRow(
      generator,
      'Subtotal',
      CurrencyFormatter.formatNumber(order.subtotal),
      totalWidth: charsPerLine,
    );
    if (order.taxAmount > 0) {
      bytes += _renderRow(
        generator,
        'Pajak (${order.taxPercentage.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(order.taxAmount),
        totalWidth: charsPerLine,
      );
    }
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += _renderRow(
      generator,
      'TOTAL TAGIHAN',
      CurrencyFormatter.formatNumber(order.grandTotal),
      bold: true,
      totalWidth: charsPerLine,
    );
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Warning Footer
    bytes += generator.text(centerText('* Ini BUKAN bukti pembayaran *', width: charsPerLine), styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(centerText('sah. Silakan bawa tagihan ini', width: charsPerLine), styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(centerText('ke meja kasir.', width: charsPerLine), styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(4);
    if (autoCut) {
      bytes += generator.cut();
    }

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
    PaperSize paperSize = PaperSize.mm58,
    int charsPerLine = 32,
    bool autoCut = false,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final cashier = await _resolveCashierName(cashierNama);

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    // Banner Header
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('PESANAN DAPUR', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Metadata
    if (order.isTakeAway) {
      bytes += generator.text('Order     : TAKE AWAY', styles: const PosStyles(align: PosAlign.left, bold: true));
    } else {
      bytes += generator.text('Meja      : ${order.tableNama ?? '-'}', styles: const PosStyles(align: PosAlign.left));
    }
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bytes += generator.text('Nama      : ${order.customerName}', styles: const PosStyles(align: PosAlign.left, bold: true));
    }
    bytes += generator.text('Batch : ${waveInfo ?? '#1 (Baru)'}', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Waktu     : $nowStr', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Kasir     : $cashier', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('QTY  ITEM', styles: const PosStyles(align: PosAlign.left, bold: true));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    // Items List
    for (var item in itemsToPrint) {
      final qtyStr = item.qty.toString().padLeft(2);
      bytes += generator.text('$qtyStr   ${item.produkNama}', styles: const PosStyles(align: PosAlign.left, bold: true));
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('     - ${item.catatan}', styles: const PosStyles(align: PosAlign.left));
      }
    }

    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(4);
    if (autoCut) {
      bytes += generator.cut();
    }

    return bytes;
  }

  // --------------------------------------------------------------------------
  // 3. STRUK PEMBAYARAN (Customer Payment Receipt)
  // --------------------------------------------------------------------------
  static Future<List<int>> generateCashierReceipt({
    required TransactionHeader transaction,
    required List<TransactionItem> items,
    String? tableName,
    PaperSize paperSize = PaperSize.mm58,
    int charsPerLine = 32,
    bool autoCut = false,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt);
    final cashier = await _resolveCashierName(transaction.cashierNama);

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    // Store Info Header
    bytes += generator.text(storeName, styles: const PosStyles(align: PosAlign.center, bold: true));
    for (var line in storeAddress.split('\n')) {
      bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
    }
    if (storePhone.isNotEmpty) {
      bytes += generator.text('Telp: $storePhone', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Metadata
    bytes += generator.text('Tgl   : $dateStr', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Kasir : $cashier', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('No.   : ${transaction.nomorTransaksi}', styles: const PosStyles(align: PosAlign.left));
    if (transaction.orderType == 'take_away') {
      bytes += generator.text('Order : TAKE AWAY', styles: const PosStyles(align: PosAlign.left, bold: true));
    } else if (tableName != null && tableName.isNotEmpty) {
      bytes += generator.text('Meja  : $tableName', styles: const PosStyles(align: PosAlign.left));
    }
    if (transaction.customerName != null && transaction.customerName!.isNotEmpty) {
      bytes += generator.text('Nama  : ${transaction.customerName}', styles: const PosStyles(align: PosAlign.left, bold: true));
    }
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    // Items List
    for (var item in items) {
      bytes += generator.text('${item.qty}x ${item.produkNama}', styles: const PosStyles(align: PosAlign.left));
      final unitPrice = CurrencyFormatter.formatNumber(item.produkHarga);
      final subtotal = CurrencyFormatter.formatNumber(item.subtotal);
      final qtyPrice = '  @ $unitPrice';
      bytes += _renderRow(generator, qtyPrice, subtotal, totalWidth: charsPerLine);

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        bytes += generator.text('     - ${item.catatan}', styles: const PosStyles(align: PosAlign.left));
      }
    }

    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    // Summary Totals
    bytes += _renderRow(
      generator,
      'Subtotal',
      CurrencyFormatter.formatNumber(transaction.subtotal),
      totalWidth: charsPerLine,
    );
    if (transaction.taxAmount > 0) {
      bytes += _renderRow(
        generator,
        'Pajak (${transaction.taxPercentage.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(transaction.taxAmount),
        totalWidth: charsPerLine,
      );
    }
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += _renderRow(
      generator,
      'TOTAL',
      CurrencyFormatter.formatNumber(transaction.grandTotal),
      bold: true,
      totalWidth: charsPerLine,
    );
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Payment & Change
    bytes += _renderRow(
      generator,
      transaction.paymentMethodNama.isEmpty ? 'Tunai' : transaction.paymentMethodNama,
      CurrencyFormatter.formatNumber(transaction.nominalBayar),
      totalWidth: charsPerLine,
    );
    bytes += _renderRow(
      generator,
      'Kembalian',
      CurrencyFormatter.formatNumber(transaction.kembalian),
      totalWidth: charsPerLine,
    );
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Footer
    bytes += generator.text('Terima Kasih Atas', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Kunjungan Anda!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(4);
    if (autoCut) {
      bytes += generator.cut();
    }

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
    PaperSize paperSize = PaperSize.mm58,
    int charsPerLine = 32,
    bool autoCut = false,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    final String cashier = await _resolveCashierName(cashierNama);
    final String nowFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final String start = startTimeStr ?? '$dateStr 08:00';
    final String end = endTimeStr ?? nowFormatted;
    final int itemsCount = totalItemsCount ?? topProducts.fold<int>(0, (sum, p) => sum + ((p['qty'] as num?)?.toInt() ?? 0));

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    // Shift Header Banner
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('TUTUP SHIFT KASIR', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Metadata
    bytes += generator.text('Kasir   : $cashier', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Mulai   : $start', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Selesai : $end', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    // Revenue Breakdown Header
    bytes += generator.text('RINCIAN PENDAPATAN', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Total Transaksi : $totalTransactions', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Total Item      : $itemsCount', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('', styles: const PosStyles(align: PosAlign.left));

    // Payment Methods Breakdown
    paymentBreakdown.forEach((method, total) {
      if (total >= 0) {
        bytes += _renderRow(generator, method, CurrencyFormatter.formatNumber(total), totalWidth: charsPerLine);
      }
    });

    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += _renderRow(
      generator,
      'TOTAL OMZET',
      CurrencyFormatter.formatNumber(totalSales),
      bold: true,
      totalWidth: charsPerLine,
    );
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Top 5 Best Selling Products Section
    if (topProducts.isNotEmpty) {
      bytes += generator.text('5 PRODUK TERLARIS', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
      final top5 = topProducts.take(5).toList();
      for (var p in top5) {
        final nama = (p['nama'] ?? p['name'] ?? p['produk_nama'] ?? 'Produk').toString();
        final qty = (p['qty'] ?? 0).toString();
        bytes += _renderRow(generator, nama, '${qty}x', totalWidth: charsPerLine);
      }
      bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));
    }

    // Physical Cash Reconciliation Banner
    final double expCash = expectedCash ?? (paymentBreakdown['Tunai'] ?? totalSales);
    final double actCash = actualCash ?? expCash;
    final double diffCash = selisihCash ?? (actCash - expCash);

    bytes += generator.text('PENCOCOKAN KAS FISIK (TUNAI)', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += _renderRow(generator, 'Sistem (Expected)', CurrencyFormatter.formatNumber(expCash), totalWidth: charsPerLine);
    bytes += _renderRow(generator, 'Laci Kas (Actual)', CurrencyFormatter.formatNumber(actCash), totalWidth: charsPerLine);
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += _renderRow(generator, 'SELISIH', CurrencyFormatter.formatNumber(diffCash), bold: true, totalWidth: charsPerLine);
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    // Footer
    bytes += generator.text('Validasi Sistem POS', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(4);
    if (autoCut) {
      bytes += generator.cut();
    }

    return bytes;
  }

  // Helper method to format left-aligned label and right-aligned value in custom character line
  static List<int> _renderRow(
    Generator generator,
    String left,
    String right, {
    bool bold = false,
    int totalWidth = 32,
  }) {
    final spaceCount = totalWidth - left.length - right.length;
    if (spaceCount > 0) {
      final line = '$left${' ' * spaceCount}$right';
      return generator.text(line, styles: PosStyles(bold: bold, align: PosAlign.left));
    } else {
      List<int> rBytes = generator.text(left, styles: PosStyles(bold: bold, align: PosAlign.left));
      final rightSpaces = totalWidth - right.length;
      final rightLine = '${' ' * (rightSpaces > 0 ? rightSpaces : 0)}$right';
      rBytes += generator.text(rightLine, styles: PosStyles(bold: bold, align: PosAlign.left));
      return rBytes;
    }
  }

  // --------------------------------------------------------------------------
  // TEXT PREVIEW HELPERS (For Thermal Simulation Screen View)
  // --------------------------------------------------------------------------
  static String formatTextRow(String left, String right, {int width = 32}) {
    final spaces = width - left.length - right.length;
    if (spaces > 0) {
      return '$left${' ' * spaces}$right';
    }
    final rightSpaces = width - right.length;
    return '$left\n${' ' * (rightSpaces > 0 ? rightSpaces : 0)}$right';
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
    int charsPerLine = 32,
  }) async {
    final activeItems = items.where((i) => !i.isCancelled).toList();
    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final cashier = await _resolveCashierName(cashierNama);

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    final buffer = StringBuffer();
    buffer.writeln(centerText('TAGIHAN', width: charsPerLine));
    buffer.writeln(centerText(storeName, width: charsPerLine));
    for (var line in storeAddress.split('\n')) {
      buffer.writeln(centerText(line, width: charsPerLine));
    }
    if (storePhone.isNotEmpty) {
      buffer.writeln(centerText('Telp: $storePhone', width: charsPerLine));
    }
    buffer.writeln(eqLine);
    buffer.writeln('Tgl   : $nowStr');
    buffer.writeln('Kasir : $cashier');
    if (order.tableNama != null && order.tableNama!.isNotEmpty) {
      buffer.writeln('Meja  : ${order.tableNama}');
    }
    buffer.writeln('Status: BELUM DIBAYAR');
    buffer.writeln(dashLine);
    for (var item in activeItems) {
      buffer.writeln('${item.qty}x ${item.produkNama}');
      buffer.writeln(formatTextRow('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', CurrencyFormatter.formatNumber(item.subtotal), width: charsPerLine));
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        buffer.writeln('     - ${item.catatan}');
      }
    }
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('Subtotal', CurrencyFormatter.formatNumber(order.subtotal), width: charsPerLine));
    if (order.taxAmount > 0) {
      buffer.writeln(formatTextRow('Pajak (${order.taxPercentage.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(order.taxAmount), width: charsPerLine));
    }
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('TOTAL TAGIHAN', CurrencyFormatter.formatNumber(order.grandTotal), width: charsPerLine));
    buffer.writeln(eqLine);
    buffer.writeln(centerText('* Ini BUKAN bukti pembayaran *', width: charsPerLine));
    buffer.writeln(centerText('sah. Silakan bawa tagihan ini', width: charsPerLine));
    buffer.writeln(centerText('ke meja kasir.', width: charsPerLine));
    buffer.writeln(eqLine);
    return buffer.toString();
  }

  static Future<String> formatKitchenTextPreview({
    required OrderModel order,
    required List<OrderItemModel> itemsToPrint,
    String? waveInfo,
    String? cashierNama,
    int charsPerLine = 32,
  }) async {
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final cashier = await _resolveCashierName(cashierNama);

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    final buffer = StringBuffer();
    buffer.writeln(eqLine);
    buffer.writeln(centerText('PESANAN DAPUR', width: charsPerLine));
    buffer.writeln(eqLine);
    buffer.writeln('Meja      : ${order.tableNama ?? '04'}');
    buffer.writeln('Batch : ${waveInfo ?? '#1 (Baru)'}');
    buffer.writeln('Waktu     : $nowStr');
    buffer.writeln('Kasir     : $cashier');
    buffer.writeln(dashLine);
    buffer.writeln('QTY  ITEM');
    buffer.writeln(dashLine);
    for (var item in itemsToPrint) {
      final qtyStr = item.qty.toString().padLeft(2);
      buffer.writeln('$qtyStr   ${item.produkNama}');
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        buffer.writeln('     - ${item.catatan}');
      }
    }
    buffer.writeln(eqLine);
    return buffer.toString();
  }

  static Future<String> formatCashierTextPreview({
    required TransactionHeader transaction,
    required List<TransactionItem> items,
    String? tableName,
    int charsPerLine = 32,
  }) async {
    final storage = SecureStorageService();
    final storeName = await storage.getStoreName() ?? 'KOS QAEZAR KAFE';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Kalimantan No. 45\nJember, Jawa Timur';
    final storePhone = await storage.getStorePhone() ?? '0812345678';
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt);
    final cashier = await _resolveCashierName(transaction.cashierNama);

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    final buffer = StringBuffer();
    buffer.writeln(centerText(storeName, width: charsPerLine));
    for (var line in storeAddress.split('\n')) {
      buffer.writeln(centerText(line, width: charsPerLine));
    }
    if (storePhone.isNotEmpty) {
      buffer.writeln(centerText('Telp: $storePhone', width: charsPerLine));
    }
    buffer.writeln(eqLine);
    buffer.writeln('Tgl   : $dateStr');
    buffer.writeln('Kasir : $cashier');
    buffer.writeln('No.   : ${transaction.nomorTransaksi}');
    if (tableName != null && tableName.isNotEmpty) {
      buffer.writeln('Meja  : $tableName');
    }
    buffer.writeln(dashLine);
    for (var item in items) {
      buffer.writeln('${item.qty}x ${item.produkNama}');
      buffer.writeln(formatTextRow('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', CurrencyFormatter.formatNumber(item.subtotal), width: charsPerLine));
      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        buffer.writeln('     - ${item.catatan}');
      }
    }
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('Subtotal', CurrencyFormatter.formatNumber(transaction.subtotal), width: charsPerLine));
    if (transaction.taxAmount > 0) {
      buffer.writeln(formatTextRow('Pajak (${transaction.taxPercentage.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(transaction.taxAmount), width: charsPerLine));
    }
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('TOTAL', CurrencyFormatter.formatNumber(transaction.grandTotal), width: charsPerLine));
    buffer.writeln(eqLine);
    buffer.writeln(formatTextRow(transaction.paymentMethodNama.isEmpty ? 'Tunai' : transaction.paymentMethodNama, CurrencyFormatter.formatNumber(transaction.nominalBayar), width: charsPerLine));
    buffer.writeln(formatTextRow('Kembalian', CurrencyFormatter.formatNumber(transaction.kembalian), width: charsPerLine));
    buffer.writeln(eqLine);
    buffer.writeln(centerText('Terima Kasih Atas', width: charsPerLine));
    buffer.writeln(centerText('Kunjungan Anda!', width: charsPerLine));
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
    int charsPerLine = 32,
  }) async {
    final String cashier = await _resolveCashierName(cashierNama);
    final String nowFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final String start = startTimeStr ?? '$dateStr 08:00';
    final String end = endTimeStr ?? nowFormatted;
    final int itemsCount = totalItemsCount ?? topProducts.fold<int>(0, (sum, p) => sum + ((p['qty'] as num?)?.toInt() ?? 0));

    final double expCash = expectedCash ?? (paymentBreakdown['Tunai'] ?? totalSales);
    final double actCash = actualCash ?? expCash;
    final double diffCash = selisihCash ?? (actCash - expCash);

    final eqLine = _equalsDivider(charsPerLine);
    final dashLine = _dashDivider(charsPerLine);

    final buffer = StringBuffer();
    buffer.writeln(eqLine);
    buffer.writeln(centerText('TUTUP SHIFT KASIR', width: charsPerLine));
    buffer.writeln(eqLine);
    buffer.writeln('Kasir   : $cashier');
    buffer.writeln('Mulai   : $start');
    buffer.writeln('Selesai : $end');
    buffer.writeln(dashLine);
    buffer.writeln(centerText('RINCIAN PENDAPATAN', width: charsPerLine));
    buffer.writeln(dashLine);
    buffer.writeln('Total Transaksi : $totalTransactions');
    buffer.writeln('Total Item      : $itemsCount');
    buffer.writeln('');
    paymentBreakdown.forEach((method, total) {
      if (total >= 0) {
        buffer.writeln(formatTextRow(method, CurrencyFormatter.formatNumber(total), width: charsPerLine));
      }
    });
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('TOTAL OMZET', CurrencyFormatter.formatNumber(totalSales), width: charsPerLine));
    buffer.writeln(eqLine);
    if (topProducts.isNotEmpty) {
      buffer.writeln(centerText('5 PRODUK TERLARIS', width: charsPerLine));
      buffer.writeln(dashLine);
      final top5 = topProducts.take(5).toList();
      for (var p in top5) {
        final nama = (p['nama'] ?? p['name'] ?? p['produk_nama'] ?? 'Produk').toString();
        final qty = (p['qty'] ?? 0).toString();
        buffer.writeln(formatTextRow(nama, '${qty}x', width: charsPerLine));
      }
      buffer.writeln(eqLine);
    }
    buffer.writeln(centerText('PENCOCOKAN KAS FISIK (TUNAI)', width: charsPerLine));
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('Sistem (Expected)', CurrencyFormatter.formatNumber(expCash), width: charsPerLine));
    buffer.writeln(formatTextRow('Laci Kas (Actual)', CurrencyFormatter.formatNumber(actCash), width: charsPerLine));
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('SELISIH', CurrencyFormatter.formatNumber(diffCash), width: charsPerLine));
    buffer.writeln(eqLine);
    buffer.writeln(centerText('Validasi Sistem POS', width: charsPerLine));
    return buffer.toString();
  }
}
