import 'dart:convert';
import '../../../product/domain/models/product_modifier.dart';
import '../../../../core/utils/currency_formatter.dart';

class TransactionHeader {
  final String id;
  final String nomorTransaksi;
  final String? masterOrderId;
  final double subtotal;
  final double discountPercentage;
  final double discountAmount;
  final double taxPercentage;
  final double taxAmount;
  final double serviceChargePercentage;
  final double serviceChargeAmount;
  final int serviceChargeAfterTax; // 1 = compound after tax, 0 = before tax
  final double grandTotal;
  final double? onlinePlatformTotal;
  final double? platformDifference;
  final String? onlinePlatform;
  final String paymentMethodId;
  final String paymentMethodNama;
  final double nominalBayar;
  final double kembalian;
  final String? catatan;
  final String? customerName;
  final String orderType; // 'dine_in' or 'take_away'
  final String status; // 'completed', 'cancelled', 'voided'
  final DateTime createdAt;
  final String? cashierId;
  final String? cashierNama;

  const TransactionHeader({
    required this.id,
    required this.nomorTransaksi,
    this.masterOrderId,
    required this.subtotal,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    required this.taxPercentage,
    required this.taxAmount,
    this.serviceChargePercentage = 0.0,
    this.serviceChargeAmount = 0.0,
    this.serviceChargeAfterTax = 0,
    required this.grandTotal,
    this.onlinePlatformTotal,
    this.platformDifference,
    this.onlinePlatform,
    required this.paymentMethodId,
    required this.paymentMethodNama,
    required this.nominalBayar,
    required this.kembalian,
    this.catatan,
    this.customerName,
    this.orderType = 'dine_in',
    this.status = 'completed',
    required this.createdAt,
    this.cashierId,
    this.cashierNama,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomor_transaksi': nomorTransaksi,
      'master_order_id': masterOrderId,
      'subtotal': subtotal,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      'tax_percentage': taxPercentage,
      'tax_amount': taxAmount,
      'service_charge_percentage': serviceChargePercentage,
      'service_charge_amount': serviceChargeAmount,
      'service_charge_after_tax': serviceChargeAfterTax,
      'grand_total': grandTotal,
      'online_platform_total': onlinePlatformTotal,
      'platform_difference': platformDifference,
      'online_platform': onlinePlatform,
      'payment_method_id': paymentMethodId,
      'payment_method_nama': paymentMethodNama,
      'nominal_bayar': nominalBayar,
      'kembalian': kembalian,
      'catatan': catatan,
      'customer_name': customerName,
      'order_type': orderType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'cashier_id': cashierId,
      'cashier_nama': cashierNama,
    };
  }

  factory TransactionHeader.fromMap(Map<String, dynamic> map) {
    return TransactionHeader(
      id: map['id'] as String,
      nomorTransaksi: map['nomor_transaksi'] as String,
      masterOrderId: map['master_order_id'] as String?,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountPercentage: ((map['discount_percentage'] ?? map['diskon_percentage']) as num?)?.toDouble() ?? 0.0,
      discountAmount: ((map['discount_amount'] ?? map['diskon_amount']) as num?)?.toDouble() ?? 0.0,
      taxPercentage: ((map['tax_percentage'] as num?) ?? 0.0).toDouble(),
      taxAmount: ((map['tax_amount'] as num?) ?? 0.0).toDouble(),
      serviceChargePercentage: ((map['service_charge_percentage'] as num?) ?? 0.0).toDouble(),
      serviceChargeAmount: ((map['service_charge_amount'] as num?) ?? 0.0).toDouble(),
      serviceChargeAfterTax: (map['service_charge_after_tax'] as int?) ?? 0,
      grandTotal: (map['grand_total'] as num).toDouble(),
      onlinePlatformTotal: (map['online_platform_total'] as num?)?.toDouble(),
      platformDifference: (map['platform_difference'] as num?)?.toDouble(),
      onlinePlatform: map['online_platform'] as String?,
      paymentMethodId: map['payment_method_id'] as String,
      paymentMethodNama: map['payment_method_nama'] as String,
      nominalBayar: (map['nominal_bayar'] as num).toDouble(),
      kembalian: (map['kembalian'] as num).toDouble(),
      catatan: map['catatan'] as String?,
      customerName: map['customer_name'] as String?,
      orderType: (map['order_type'] as String?) ?? 'dine_in',
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      cashierId: map['cashier_id'] as String?,
      cashierNama: map['cashier_nama'] as String?,
    );
  }
}

class TransactionItem {
  final String id;
  final String transactionId;
  final String produkId;
  final String produkNama;
  final double produkHarga;
  final int qty;
  final double subtotal;
  final double discountPercentage;
  final double discountAmount;
  final String? catatan;
  final List<SelectedModifier> selectedModifiers;

  const TransactionItem({
    required this.id,
    required this.transactionId,
    required this.produkId,
    required this.produkNama,
    required this.produkHarga,
    required this.qty,
    required this.subtotal,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    this.catatan,
    this.selectedModifiers = const [],
  });

  bool get hasDiscount => discountAmount > 0;
  bool get hasModifiers => selectedModifiers.isNotEmpty;

  String get modifierSignature {
    if (selectedModifiers.isEmpty) return '';
    final sigs = selectedModifiers.map((m) => '${m.groupId}:${m.optionId}').toList()..sort();
    return sigs.join('|');
  }

  double get modifierUnitPrice => selectedModifiers.fold<double>(0.0, (sum, m) => sum + m.harga);
  double get effectiveUnitPrice => (produkHarga + modifierUnitPrice);

  String get modifiersSummary => selectedModifiers
      .map((m) => '${m.optionName}${m.harga > 0 ? ' (+${CurrencyFormatter.format(m.harga)})' : ''}')
      .join(', ');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'produk_id': produkId,
      'produk_nama': produkNama,
      'produk_harga': produkHarga,
      'qty': qty,
      'subtotal': subtotal,
      'diskon_percentage': discountPercentage,
      'diskon_amount': discountAmount,
      'catatan': catatan,
      'modifier_details': selectedModifiers.isNotEmpty
          ? jsonEncode(selectedModifiers.map((m) => m.toMap()).toList())
          : null,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    List<SelectedModifier> parsedModifiers = const [];
    final rawModifiers = map['modifier_details'] as String?;
    if (rawModifiers != null && rawModifiers.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawModifiers) as List;
        parsedModifiers = decoded.map((m) => SelectedModifier.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      } catch (_) {}
    }

    return TransactionItem(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      produkId: map['produk_id'] as String,
      produkNama: map['produk_nama'] as String,
      produkHarga: (map['produk_harga'] as num).toDouble(),
      qty: map['qty'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountPercentage: ((map['diskon_percentage'] ?? map['discount_percentage']) as num?)?.toDouble() ?? 0.0,
      discountAmount: ((map['diskon_amount'] ?? map['discount_amount']) as num?)?.toDouble() ?? 0.0,
      catatan: map['catatan'] as String?,
      selectedModifiers: parsedModifiers,
    );
  }
}
