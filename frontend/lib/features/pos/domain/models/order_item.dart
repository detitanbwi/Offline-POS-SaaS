import 'dart:convert';
import '../../../product/domain/models/product_modifier.dart';
import '../../../../core/utils/currency_formatter.dart';

class OrderItemModel {
  final String id;
  final String orderId; // legacy order ID or master order ID
  final String? masterOrderId;
  final String? batchId;
  final String produkId;
  final String produkNama;
  final double produkHarga;
  final double basePrice;
  final double effectivePrice;
  final int qty; // active quantity
  final int qtyOrdered;
  final int qtyPaid;
  final int cancelledQty;
  final double subtotal;
  final String? catatan;
  final int statusCetak; // 0 = not printed, 1 = printed to kitchen
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancelledReason;
  final String? cancelledByManagerId;
  final String? printBatchId;
  final double discountPercentage;
  final double discountAmount;
  final List<SelectedModifier> selectedModifiers;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    this.masterOrderId,
    this.batchId,
    required this.produkId,
    required this.produkNama,
    required this.produkHarga,
    this.basePrice = 0.0,
    this.effectivePrice = 0.0,
    required this.qty,
    int? qtyOrdered,
    this.qtyPaid = 0,
    this.cancelledQty = 0,
    required this.subtotal,
    this.catatan,
    this.statusCetak = 0,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancelledReason,
    this.cancelledByManagerId,
    this.printBatchId,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    this.selectedModifiers = const [],
  }) : qtyOrdered = qtyOrdered ?? qty;

  int get remainingUnpaidQty => (qtyOrdered - qtyPaid - cancelledQty).clamp(0, 999999);
  bool get isFullyPaid => qtyPaid >= (qtyOrdered - cancelledQty);
  bool get isManual => produkId.startsWith('manual_');
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

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? masterOrderId,
    String? batchId,
    String? produkId,
    String? produkNama,
    double? produkHarga,
    double? basePrice,
    double? effectivePrice,
    int? qty,
    int? qtyOrdered,
    int? qtyPaid,
    int? cancelledQty,
    double? subtotal,
    String? catatan,
    int? statusCetak,
    bool? isCancelled,
    DateTime? cancelledAt,
    String? cancelledReason,
    String? cancelledByManagerId,
    String? printBatchId,
    double? discountPercentage,
    double? discountAmount,
    List<SelectedModifier>? selectedModifiers,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      masterOrderId: masterOrderId ?? this.masterOrderId,
      batchId: batchId ?? this.batchId,
      produkId: produkId ?? this.produkId,
      produkNama: produkNama ?? this.produkNama,
      produkHarga: produkHarga ?? this.produkHarga,
      basePrice: basePrice ?? this.basePrice,
      effectivePrice: effectivePrice ?? this.effectivePrice,
      qty: qty ?? this.qty,
      qtyOrdered: qtyOrdered ?? this.qtyOrdered,
      qtyPaid: qtyPaid ?? this.qtyPaid,
      cancelledQty: cancelledQty ?? this.cancelledQty,
      subtotal: subtotal ?? this.subtotal,
      catatan: catatan ?? this.catatan,
      statusCetak: statusCetak ?? this.statusCetak,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledByManagerId: cancelledByManagerId ?? this.cancelledByManagerId,
      printBatchId: printBatchId ?? this.printBatchId,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'master_order_id': masterOrderId ?? orderId,
      'batch_id': batchId,
      'produk_id': produkId,
      'produk_nama': produkNama,
      'produk_harga': produkHarga,
      'base_price': basePrice > 0 ? basePrice : produkHarga,
      'effective_price': effectivePrice > 0 ? effectivePrice : produkHarga,
      'qty': qty,
      'qty_ordered': qtyOrdered,
      'qty_paid': qtyPaid,
      'cancelled_qty': cancelledQty,
      'subtotal': subtotal,
      'catatan': catatan,
      'status_cetak': statusCetak,
      'is_cancelled': isCancelled ? 1 : 0,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancelled_reason': cancelledReason,
      'cancelled_by_manager_id': cancelledByManagerId,
      'print_batch_id': printBatchId,
      'diskon_percentage': discountPercentage,
      'diskon_amount': discountAmount,
      'modifier_details': selectedModifiers.isNotEmpty
          ? jsonEncode(selectedModifiers.map((m) => m.toMap()).toList())
          : null,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final qtyVal = map['qty'] as int;
    final produkHargaVal = (map['produk_harga'] as num).toDouble();

    List<SelectedModifier> parsedModifiers = const [];
    final rawModifiers = map['modifier_details'] as String?;
    if (rawModifiers != null && rawModifiers.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawModifiers) as List;
        parsedModifiers = decoded.map((m) => SelectedModifier.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      } catch (_) {}
    }

    return OrderItemModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      masterOrderId: map['master_order_id'] as String?,
      batchId: map['batch_id'] as String?,
      produkId: map['produk_id'] as String,
      produkNama: map['produk_nama'] as String,
      produkHarga: produkHargaVal,
      basePrice: (map['base_price'] as num?)?.toDouble() ?? produkHargaVal,
      effectivePrice: (map['effective_price'] as num?)?.toDouble() ?? produkHargaVal,
      qty: qtyVal,
      qtyOrdered: (map['qty_ordered'] as num?)?.toInt() ?? qtyVal,
      qtyPaid: (map['qty_paid'] as num?)?.toInt() ?? 0,
      cancelledQty: (map['cancelled_qty'] as num?)?.toInt() ?? 0,
      subtotal: (map['subtotal'] as num).toDouble(),
      catatan: map['catatan'] as String?,
      statusCetak: (map['status_cetak'] as num?)?.toInt() ?? 0,
      isCancelled: (map['is_cancelled'] as int?) == 1,
      cancelledAt: map['cancelled_at'] != null ? DateTime.parse(map['cancelled_at'] as String) : null,
      cancelledReason: map['cancelled_reason'] as String?,
      cancelledByManagerId: map['cancelled_by_manager_id'] as String?,
      printBatchId: map['print_batch_id'] as String?,
      discountPercentage: ((map['diskon_percentage'] ?? map['discount_percentage']) as num?)?.toDouble() ?? 0.0,
      discountAmount: ((map['diskon_amount'] ?? map['discount_amount']) as num?)?.toDouble() ?? 0.0,
      selectedModifiers: parsedModifiers,
    );
  }
}
