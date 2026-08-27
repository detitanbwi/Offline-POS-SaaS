import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../database/pos_database.dart';
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

  static String _equalsDivider(int width) => '=' * width;
  static String _dashDivider(int width) => '-' * width;

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
            discountAmount: existing.discountAmount + item.discountAmount,
            discountPercentage: existing.discountPercentage > 0 ? existing.discountPercentage : item.discountPercentage,
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
    final cashier = await _resolveCashierName(cashierNama ?? order.cashierNama);

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
      final pName = order.onlinePlatform != null && order.onlinePlatform!.isNotEmpty ? ' (${order.onlinePlatform})' : '';
      bytes += generator.text('Order : TAKE AWAY$pName', styles: const PosStyles(align: PosAlign.left, bold: true));
    } else if (order.tableNama != null && order.tableNama!.isNotEmpty) {
      bytes += generator.text('Meja  : ${order.tableNama}', styles: const PosStyles(align: PosAlign.left));
    }
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bytes += generator.text('Nama  : ${order.customerName}', styles: const PosStyles(align: PosAlign.left, bold: true));
    }
    bytes += generator.text('Status: BELUM DIBAYAR', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    final productIds = activeItems.map((i) => i.produkId).toList();
    final packageComponents = await _getPackageComponents(productIds);
    final displayItems = _consolidateOrderItems(activeItems, packageComponents);

    // Items Listing
    for (var item in displayItems) {
      bytes += generator.text('${item.qty}x ${item.produkNama}', styles: const PosStyles(align: PosAlign.left));
      final unitPrice = CurrencyFormatter.formatNumber(item.produkHarga);
      final subtotal = CurrencyFormatter.formatNumber(item.subtotal);
      final qtyPrice = '  @ $unitPrice';
      bytes += _renderRow(generator, qtyPrice, subtotal, totalWidth: charsPerLine);

      // Package sub-items bullet
      final comps = packageComponents[item.produkId] ?? [];
      for (var comp in comps) {
        final compQty = (comp['qty'] as int) * item.qty;
        final compNama = comp['product_nama'] as String;
        bytes += generator.text('   • ${compQty}x $compNama', styles: const PosStyles(align: PosAlign.left));
      }

      if (item.hasModifiers) {
        for (var m in item.selectedModifiers) {
          final modPrice = m.harga > 0 ? ' (+${CurrencyFormatter.formatNumber(m.harga)})' : '';
          final modText = '${m.optionName}$modPrice';
          final wrappedMod = wrapTextWithIndent(modText, charsPerLine, firstLineIndent: '  + ', otherLinesIndent: '    ');
          for (var l in wrappedMod) {
            bytes += generator.text(l, styles: const PosStyles(align: PosAlign.left));
          }
        }
      }

      if (item.discountAmount > 0) {
        final discTag = '  (Disc -${item.discountPercentage > 0 ? '${item.discountPercentage.toStringAsFixed(0)}% ' : ''}${CurrencyFormatter.formatNumber(item.discountAmount)})';
        bytes += generator.text(discTag, styles: const PosStyles(align: PosAlign.left));
      }

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        final wrappedNotes = wrapTextWithIndent(item.catatan!.trim(), charsPerLine, firstLineIndent: '     - ', otherLinesIndent: '       ');
        for (var noteLine in wrappedNotes) {
          bytes += generator.text(noteLine, styles: const PosStyles(align: PosAlign.left));
        }
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
    if (order.discountAmount > 0) {
      bytes += _renderRow(
        generator,
        'Diskon Nota${order.discountPercentage > 0 ? ' (${order.discountPercentage.toStringAsFixed(0)}%)' : ''}',
        '-${CurrencyFormatter.formatNumber(order.discountAmount)}',
        totalWidth: charsPerLine,
      );
    }
    final (scAmount, scRate) = _resolveOrderServiceCharge(order);
    if (scAmount > 0) {
      bytes += _renderRow(
        generator,
        'Service (${scRate.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(scAmount),
        totalWidth: charsPerLine,
      );
    }
    if (order.taxAmount > 0) {
      bytes += _renderRow(
        generator,
        'Pajak (${order.taxPercentage.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(order.taxAmount),
        totalWidth: charsPerLine,
      );
    }
    final storeTotal = order.subtotal + scAmount + order.taxAmount;
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += _renderRow(
      generator,
      'TOTAL',
      CurrencyFormatter.formatNumber(order.onlinePlatformTotal != null && order.onlinePlatformTotal! > 0 ? storeTotal : order.grandTotal),
      bold: true,
      totalWidth: charsPerLine,
    );
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    if (order.onlinePlatformTotal != null && order.onlinePlatformTotal! > 0) {
      final diff = (order.platformDifference != null && order.platformDifference != 0)
          ? order.platformDifference!
          : (order.onlinePlatformTotal! - storeTotal);
      final platformLabel = order.onlinePlatform != null && order.onlinePlatform!.isNotEmpty
          ? 'Total Aplikasi (${order.onlinePlatform})'
          : 'Total Aplikasi';
      bytes += _renderRow(
        generator,
        'Komisi Online',
        CurrencyFormatter.formatNumber(diff.abs()),
        totalWidth: charsPerLine,
      );
      bytes += _renderRow(
        generator,
        platformLabel,
        CurrencyFormatter.formatNumber(order.onlinePlatformTotal!),
        bold: true,
        totalWidth: charsPerLine,
      );
      bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    }
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
    bytes += generator.text('No. Order : ${order.nomorOrder}', styles: const PosStyles(align: PosAlign.left, bold: true));
    if (order.isTakeAway) {
      final platformSuffix = (order.onlinePlatform != null && order.onlinePlatform!.trim().isNotEmpty)
          ? ' (${order.onlinePlatform!.trim()})'
          : '';
      bytes += generator.text('Order     : TAKE AWAY$platformSuffix', styles: const PosStyles(align: PosAlign.left, bold: true));
    } else {
      bytes += generator.text('Meja      : ${order.tableNama ?? '-'}', styles: const PosStyles(align: PosAlign.left, bold: true));
    }
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      bytes += generator.text('Nama      : ${order.customerName!.trim()}', styles: const PosStyles(align: PosAlign.left, bold: true));
    }
    bytes += generator.text('Batch : ${waveInfo ?? '#1 (Baru)'}', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Waktu     : $nowStr', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Kasir     : $cashier', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('QTY  ITEM', styles: const PosStyles(align: PosAlign.left, bold: true));
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    final productIds = itemsToPrint.map((i) => i.produkId).toList();
    final packageComponents = await _getPackageComponents(productIds);

    // Items List
    for (var item in itemsToPrint) {
      final qtyStr = item.qty.toString().padLeft(2);
      bytes += generator.text('$qtyStr   ${item.produkNama}', styles: const PosStyles(align: PosAlign.left, bold: true));
      
      // Package sub-items bullet for kitchen
      final comps = packageComponents[item.produkId] ?? [];
      for (var comp in comps) {
        final compQty = (comp['qty'] as int) * item.qty;
        final compNama = comp['product_nama'] as String;
        bytes += generator.text('     • ${compQty}x $compNama', styles: const PosStyles(align: PosAlign.left));
      }

      if (item.hasModifiers) {
        for (var m in item.selectedModifiers) {
          final wrappedMod = wrapTextWithIndent(m.optionName, charsPerLine, firstLineIndent: '    + ', otherLinesIndent: '      ');
          for (var l in wrappedMod) {
            bytes += generator.text(l, styles: const PosStyles(align: PosAlign.left));
          }
        }
      }

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        final wrappedNotes = wrapTextWithIndent(item.catatan!.trim(), charsPerLine, firstLineIndent: '     - ', otherLinesIndent: '       ');
        for (var noteLine in wrappedNotes) {
          bytes += generator.text(noteLine, styles: const PosStyles(align: PosAlign.left));
        }
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
      final pName = transaction.onlinePlatform != null && transaction.onlinePlatform!.isNotEmpty ? ' (${transaction.onlinePlatform})' : '';
      bytes += generator.text('Order : TAKE AWAY$pName', styles: const PosStyles(align: PosAlign.left, bold: true));
    } else if (tableName != null && tableName.isNotEmpty) {
      bytes += generator.text('Meja  : $tableName', styles: const PosStyles(align: PosAlign.left));
    }
    if (transaction.customerName != null && transaction.customerName!.isNotEmpty) {
      bytes += generator.text('Nama  : ${transaction.customerName}', styles: const PosStyles(align: PosAlign.left, bold: true));
    }
    bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));

    final txProductIds = items.map((i) => i.produkId).toList();
    final txPackageComponents = await _getPackageComponents(txProductIds);
    final displayItems = _consolidateTransactionItems(items, txPackageComponents);

    // Items List
    for (var item in displayItems) {
      bytes += generator.text('${item.qty}x ${item.produkNama}', styles: const PosStyles(align: PosAlign.left));
      final unitPrice = CurrencyFormatter.formatNumber(item.produkHarga);
      final subtotal = CurrencyFormatter.formatNumber(item.subtotal);
      final qtyPrice = '  @ $unitPrice';
      bytes += _renderRow(generator, qtyPrice, subtotal, totalWidth: charsPerLine);

      // Package sub-items bullet
      final comps = txPackageComponents[item.produkId] ?? [];
      for (var comp in comps) {
        final compQty = (comp['qty'] as int) * item.qty;
        final compNama = comp['product_nama'] as String;
        bytes += generator.text('   • ${compQty}x $compNama', styles: const PosStyles(align: PosAlign.left));
      }

      if (item.hasModifiers) {
        for (var m in item.selectedModifiers) {
          final modPrice = m.harga > 0 ? ' (+${CurrencyFormatter.formatNumber(m.harga)})' : '';
          final modText = '${m.optionName}$modPrice';
          final wrappedMod = wrapTextWithIndent(modText, charsPerLine, firstLineIndent: '  + ', otherLinesIndent: '    ');
          for (var l in wrappedMod) {
            bytes += generator.text(l, styles: const PosStyles(align: PosAlign.left));
          }
        }
      }

      if (item.discountAmount > 0) {
        final discTag = '  (Disc -${item.discountPercentage > 0 ? '${item.discountPercentage.toStringAsFixed(0)}% ' : ''}${CurrencyFormatter.formatNumber(item.discountAmount)})';
        bytes += generator.text(discTag, styles: const PosStyles(align: PosAlign.left));
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
    if (transaction.discountAmount > 0) {
      bytes += _renderRow(
        generator,
        'Diskon Nota${transaction.discountPercentage > 0 ? ' (${transaction.discountPercentage.toStringAsFixed(0)}%)' : ''}',
        '-${CurrencyFormatter.formatNumber(transaction.discountAmount)}',
        totalWidth: charsPerLine,
      );
    }
    final (txScAmount, txScRate) = _resolveTxServiceCharge(transaction);
    if (txScAmount > 0) {
      bytes += _renderRow(
        generator,
        'Service (${txScRate.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(txScAmount),
        totalWidth: charsPerLine,
      );
    }
    if (transaction.taxAmount > 0) {
      bytes += _renderRow(
        generator,
        'Pajak (${transaction.taxPercentage.toStringAsFixed(0)}%)',
        CurrencyFormatter.formatNumber(transaction.taxAmount),
        totalWidth: charsPerLine,
      );
    }
    final storeTotal = transaction.subtotal + txScAmount + transaction.taxAmount;
    bytes += _renderRow(
      generator,
      'TOTAL',
      CurrencyFormatter.formatNumber(transaction.onlinePlatformTotal != null ? storeTotal : transaction.grandTotal),
      bold: true,
      totalWidth: charsPerLine,
    );
    bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));

    if (transaction.onlinePlatformTotal != null && transaction.onlinePlatformTotal! > 0) {
      final storeTotal = transaction.subtotal + transaction.taxAmount;
      final diff = (transaction.platformDifference != null && transaction.platformDifference != 0)
          ? transaction.platformDifference!
          : (transaction.onlinePlatformTotal! - storeTotal);
      final platformLabel = transaction.onlinePlatform != null && transaction.onlinePlatform!.isNotEmpty
          ? 'Total App (${transaction.onlinePlatform})'
          : 'Total App Online';
      bytes += _renderRow(
        generator,
        platformLabel,
        CurrencyFormatter.formatNumber(transaction.onlinePlatformTotal!),
        totalWidth: charsPerLine,
      );
      bytes += _renderRow(
        generator,
        'Selisih Komisi',
        CurrencyFormatter.formatNumber(diff.abs()),
        bold: true,
        totalWidth: charsPerLine,
      );
      bytes += generator.text(dashLine, styles: const PosStyles(align: PosAlign.left));
    }

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
    if (totalServiceCharge != null && totalServiceCharge > 0) {
      bytes += _renderRow(generator, 'Total Service', CurrencyFormatter.formatNumber(totalServiceCharge), totalWidth: charsPerLine);
    }
    if (totalTax > 0) {
      bytes += _renderRow(generator, 'Total Pajak', CurrencyFormatter.formatNumber(totalTax), totalWidth: charsPerLine);
    }
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

  static List<String> wrapTextWithIndent(String text, int width, {String firstLineIndent = '     - ', String otherLinesIndent = '       '}) {
    List<String> lines = [];
    String currentIndent = firstLineIndent;
    
    List<String> paragraphs = text.split('\n');
    for (var p in paragraphs) {
      String currentLine = currentIndent;
      List<String> words = p.split(' ');
      
      for (var word in words) {
        if (word.isEmpty) continue;
        if ((currentLine.length + word.length + (currentLine == currentIndent ? 0 : 1)) <= width) {
          if (currentLine != currentIndent) currentLine += ' ';
          currentLine += word;
        } else {
          if (currentLine != currentIndent) {
            lines.add(currentLine);
          }
          currentIndent = otherLinesIndent;
          currentLine = currentIndent + word;
          while (currentLine.length > width) {
            lines.add(currentLine.substring(0, width));
            currentLine = currentIndent + currentLine.substring(width);
          }
        }
      }
      if (currentLine != currentIndent) {
        lines.add(currentLine);
      }
      currentIndent = otherLinesIndent; 
    }
    return lines;
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
    final cashier = await _resolveCashierName(cashierNama ?? order.cashierNama);

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
    if (order.isTakeAway) {
      final pName = order.onlinePlatform != null && order.onlinePlatform!.isNotEmpty ? ' (${order.onlinePlatform})' : '';
      buffer.writeln('Order : TAKE AWAY$pName');
    } else if (order.tableNama != null && order.tableNama!.isNotEmpty) {
      buffer.writeln('Meja  : ${order.tableNama}');
    }
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buffer.writeln('Nama  : ${order.customerName}');
    }
    buffer.writeln('Status: BELUM DIBAYAR');
    buffer.writeln(dashLine);

    final productIds = activeItems.map((i) => i.produkId).toList();
    final packageComponents = await _getPackageComponents(productIds);
    final displayItems = _consolidateOrderItems(activeItems, packageComponents);

    for (var item in displayItems) {
      buffer.writeln('${item.qty}x ${item.produkNama}');
      buffer.writeln(formatTextRow('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', CurrencyFormatter.formatNumber(item.subtotal), width: charsPerLine));
      
      final comps = packageComponents[item.produkId] ?? [];
      for (var comp in comps) {
        final compQty = (comp['qty'] as int) * item.qty;
        final compNama = comp['product_nama'] as String;
        buffer.writeln('   • ${compQty}x $compNama');
      }

      if (item.hasModifiers) {
        for (var m in item.selectedModifiers) {
          final modPrice = m.harga > 0 ? ' (+${CurrencyFormatter.formatNumber(m.harga)})' : '';
          final modText = '${m.optionName}$modPrice';
          final wrappedMod = wrapTextWithIndent(modText, charsPerLine, firstLineIndent: '  + ', otherLinesIndent: '    ');
          for (var l in wrappedMod) {
            buffer.writeln(l);
          }
        }
      }

      if (item.discountAmount > 0) {
        buffer.writeln('  (Disc -${item.discountPercentage > 0 ? '${item.discountPercentage.toStringAsFixed(0)}% ' : ''}${CurrencyFormatter.formatNumber(item.discountAmount)})');
      }

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        final wrappedNotes = wrapTextWithIndent(item.catatan!.trim(), charsPerLine, firstLineIndent: '     - ', otherLinesIndent: '       ');
        for (var noteLine in wrappedNotes) {
          buffer.writeln(noteLine);
        }
      }
    }
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('Subtotal', CurrencyFormatter.formatNumber(order.subtotal), width: charsPerLine));
    if (order.discountAmount > 0) {
      buffer.writeln(formatTextRow('Diskon Nota${order.discountPercentage > 0 ? ' (${order.discountPercentage.toStringAsFixed(0)}%)' : ''}', '-${CurrencyFormatter.formatNumber(order.discountAmount)}', width: charsPerLine));
    }
    final (previewScAmount, previewScRate) = _resolveOrderServiceCharge(order);
    if (previewScAmount > 0) {
      buffer.writeln(formatTextRow('Service (${previewScRate.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(previewScAmount), width: charsPerLine));
    }
    if (order.taxAmount > 0) {
      buffer.writeln(formatTextRow('Pajak (${order.taxPercentage.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(order.taxAmount), width: charsPerLine));
    }
    final storeTotal = order.subtotal + previewScAmount + order.taxAmount - order.discountAmount;
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('TOTAL', CurrencyFormatter.formatNumber(order.onlinePlatformTotal != null && order.onlinePlatformTotal! > 0 ? storeTotal : order.grandTotal), width: charsPerLine));
    buffer.writeln(dashLine);
    if (order.onlinePlatformTotal != null && order.onlinePlatformTotal! > 0) {
      final diff = (order.platformDifference != null && order.platformDifference != 0)
          ? order.platformDifference!
          : (order.onlinePlatformTotal! - storeTotal);
      final platformLabel = order.onlinePlatform != null && order.onlinePlatform!.isNotEmpty
          ? 'Total Aplikasi (${order.onlinePlatform})'
          : 'Total Aplikasi';
      buffer.writeln(formatTextRow('Komisi Online', CurrencyFormatter.formatNumber(diff.abs()), width: charsPerLine));
      buffer.writeln(formatTextRow(platformLabel, CurrencyFormatter.formatNumber(order.onlinePlatformTotal!), width: charsPerLine));
      buffer.writeln(dashLine);
    }
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
    buffer.writeln('No. Order : ${order.nomorOrder}');
    if (order.isTakeAway) {
      final platformSuffix = (order.onlinePlatform != null && order.onlinePlatform!.trim().isNotEmpty)
          ? ' (${order.onlinePlatform!.trim()})'
          : '';
      buffer.writeln('Order     : TAKE AWAY$platformSuffix');
    } else {
      buffer.writeln('Meja      : ${order.tableNama ?? '-'}');
    }
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      buffer.writeln('Nama      : ${order.customerName!.trim()}');
    }
    buffer.writeln('Batch : ${waveInfo ?? '#1 (Baru)'}');
    buffer.writeln('Waktu     : $nowStr');
    buffer.writeln('Kasir     : $cashier');
    buffer.writeln(dashLine);
    buffer.writeln('QTY  ITEM');
    buffer.writeln(dashLine);

    final productIds = itemsToPrint.map((i) => i.produkId).toList();
    final packageComponents = await _getPackageComponents(productIds);

    for (var item in itemsToPrint) {
      final qtyStr = item.qty.toString().padLeft(2);
      buffer.writeln('$qtyStr   ${item.produkNama}');

      final comps = packageComponents[item.produkId] ?? [];
      for (var comp in comps) {
        final compQty = (comp['qty'] as int) * item.qty;
        final compNama = comp['product_nama'] as String;
        buffer.writeln('     • ${compQty}x $compNama');
      }

      if (item.hasModifiers) {
        for (var m in item.selectedModifiers) {
          final wrappedMod = wrapTextWithIndent(m.optionName, charsPerLine, firstLineIndent: '    + ', otherLinesIndent: '      ');
          for (var l in wrappedMod) {
            buffer.writeln(l);
          }
        }
      }

      if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
        final wrappedNotes = wrapTextWithIndent(item.catatan!.trim(), charsPerLine, firstLineIndent: '     - ', otherLinesIndent: '       ');
        for (var noteLine in wrappedNotes) {
          buffer.writeln(noteLine);
        }
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
    if (transaction.orderType == 'take_away') {
      final pName = transaction.onlinePlatform != null && transaction.onlinePlatform!.isNotEmpty ? ' (${transaction.onlinePlatform})' : '';
      buffer.writeln('Order : TAKE AWAY$pName');
    } else if (tableName != null && tableName.isNotEmpty) {
      buffer.writeln('Meja  : $tableName');
    }
    if (transaction.customerName != null && transaction.customerName!.isNotEmpty) {
      buffer.writeln('Nama  : ${transaction.customerName}');
    }
    buffer.writeln(dashLine);

    final txProductIds = items.map((i) => i.produkId).toList();
    final txPackageComponents = await _getPackageComponents(txProductIds);
    final displayItems = _consolidateTransactionItems(items, txPackageComponents);

    for (var item in displayItems) {
      buffer.writeln('${item.qty}x ${item.produkNama}');
      buffer.writeln(formatTextRow('  @ ${CurrencyFormatter.formatNumber(item.produkHarga)}', CurrencyFormatter.formatNumber(item.subtotal), width: charsPerLine));

      final comps = txPackageComponents[item.produkId] ?? [];
      for (var comp in comps) {
        final compQty = (comp['qty'] as int) * item.qty;
        final compNama = comp['product_nama'] as String;
        buffer.writeln('   • ${compQty}x $compNama');
      }

      if (item.hasModifiers) {
        for (var m in item.selectedModifiers) {
          final modPrice = m.harga > 0 ? ' (+${CurrencyFormatter.formatNumber(m.harga)})' : '';
          final modText = '${m.optionName}$modPrice';
          final wrappedMod = wrapTextWithIndent(modText, charsPerLine, firstLineIndent: '  + ', otherLinesIndent: '    ');
          for (var l in wrappedMod) {
            buffer.writeln(l);
          }
        }
      }

      if (item.discountAmount > 0) {
        buffer.writeln('  (Disc -${item.discountPercentage > 0 ? '${item.discountPercentage.toStringAsFixed(0)}% ' : ''}${CurrencyFormatter.formatNumber(item.discountAmount)})');
      }
    }
    buffer.writeln(dashLine);
    buffer.writeln(formatTextRow('Subtotal', CurrencyFormatter.formatNumber(transaction.subtotal), width: charsPerLine));
    if (transaction.discountAmount > 0) {
      buffer.writeln(formatTextRow('Diskon Nota${transaction.discountPercentage > 0 ? ' (${transaction.discountPercentage.toStringAsFixed(0)}%)' : ''}', '-${CurrencyFormatter.formatNumber(transaction.discountAmount)}', width: charsPerLine));
    }
    final (txPreviewScAmount, txPreviewScRate) = _resolveTxServiceCharge(transaction);
    if (txPreviewScAmount > 0) {
      buffer.writeln(formatTextRow('Service (${txPreviewScRate.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(txPreviewScAmount), width: charsPerLine));
    }
    if (transaction.taxAmount > 0) {
      buffer.writeln(formatTextRow('Pajak (${transaction.taxPercentage.toStringAsFixed(0)}%)', CurrencyFormatter.formatNumber(transaction.taxAmount), width: charsPerLine));
    }
    buffer.writeln(dashLine);
    final storeTotal = transaction.subtotal + txPreviewScAmount + transaction.taxAmount - transaction.discountAmount;
    buffer.writeln(formatTextRow('TOTAL', CurrencyFormatter.formatNumber(transaction.onlinePlatformTotal != null ? storeTotal : transaction.grandTotal), width: charsPerLine));
    buffer.writeln(eqLine);
    if (transaction.onlinePlatformTotal != null && transaction.onlinePlatformTotal! > 0) {
      final diff = (transaction.platformDifference != null && transaction.platformDifference != 0)
          ? transaction.platformDifference!
          : (transaction.onlinePlatformTotal! - storeTotal);
      final platformLabel = transaction.onlinePlatform != null && transaction.onlinePlatform!.isNotEmpty
          ? 'Total App (${transaction.onlinePlatform})'
          : 'Total App Online';
      buffer.writeln(formatTextRow(platformLabel, CurrencyFormatter.formatNumber(transaction.onlinePlatformTotal!), width: charsPerLine));
      buffer.writeln(formatTextRow('Selisih Komisi', CurrencyFormatter.formatNumber(diff.abs()), width: charsPerLine));
      buffer.writeln(dashLine);
    }
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
    if (totalServiceCharge != null && totalServiceCharge > 0) {
      buffer.writeln(formatTextRow('Total Service', CurrencyFormatter.formatNumber(totalServiceCharge), width: charsPerLine));
    }
    if (totalTax > 0) {
      buffer.writeln(formatTextRow('Total Pajak', CurrencyFormatter.formatNumber(totalTax), width: charsPerLine));
    }
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
