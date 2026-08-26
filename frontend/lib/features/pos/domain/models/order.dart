class OrderModel {
  final String id;
  final String nomorOrder;
  final String? tableId;
  final String? tableNama;
  final String? tableNomor;
  final String? customerName;
  final String orderType; // 'dine_in' or 'take_away'
  final String? takeAwaySubType;
  final String? onlinePlatform;
  final String? clearTableReason;
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
  final String status; // 'draft', 'processing', 'completed', 'cancelled'
  final String paymentStatus; // 'unpaid', 'billed', 'paid'
  final String? catatan;
  final String? cashierId;
  final String? cashierNama;
  final bool isBillPrinted;
  final DateTime? billPrintedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.nomorOrder,
    this.tableId,
    this.tableNama,
    this.tableNomor,
    this.customerName,
    this.orderType = 'dine_in',
    this.takeAwaySubType,
    this.onlinePlatform,
    this.clearTableReason,
    this.subtotal = 0.0,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    this.taxPercentage = 0.0,
    this.taxAmount = 0.0,
    this.serviceChargePercentage = 0.0,
    this.serviceChargeAmount = 0.0,
    this.serviceChargeAfterTax = 0,
    this.grandTotal = 0.0,
    this.onlinePlatformTotal,
    this.platformDifference,
    this.status = 'draft',
    this.paymentStatus = 'unpaid',
    this.catatan,
    this.cashierId,
    this.cashierNama,
    this.isBillPrinted = false,
    this.billPrintedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status == 'draft';
  bool get isProcessing => status == 'processing';
  bool get isServed => status == 'served';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isBilled => paymentStatus == 'billed';
  bool get isPartiallyPaid => paymentStatus == 'partially_paid';
  bool get isPaid => paymentStatus == 'paid';
  bool get isTakeAway => orderType == 'take_away';
  bool get hasDiscount => discountAmount > 0;

  OrderModel copyWith({
    String? id,
    String? nomorOrder,
    String? tableId,
    String? tableNama,
    String? tableNomor,
    String? customerName,
    String? orderType,
    String? takeAwaySubType,
    String? onlinePlatform,
    String? clearTableReason,
    double? subtotal,
    double? discountPercentage,
    double? discountAmount,
    double? taxPercentage,
    double? taxAmount,
    double? serviceChargePercentage,
    double? serviceChargeAmount,
    int? serviceChargeAfterTax,
    double? grandTotal,
    double? onlinePlatformTotal,
    double? platformDifference,
    String? status,
    String? paymentStatus,
    String? catatan,
    String? cashierId,
    String? cashierNama,
    bool? isBillPrinted,
    DateTime? billPrintedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      nomorOrder: nomorOrder ?? this.nomorOrder,
      tableId: tableId ?? this.tableId,
      tableNama: tableNama ?? this.tableNama,
      tableNomor: tableNomor ?? this.tableNomor,
      customerName: customerName ?? this.customerName,
      orderType: orderType ?? this.orderType,
      takeAwaySubType: takeAwaySubType ?? this.takeAwaySubType,
      onlinePlatform: onlinePlatform ?? this.onlinePlatform,
      clearTableReason: clearTableReason ?? this.clearTableReason,
      subtotal: subtotal ?? this.subtotal,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      serviceChargePercentage: serviceChargePercentage ?? this.serviceChargePercentage,
      serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
      serviceChargeAfterTax: serviceChargeAfterTax ?? this.serviceChargeAfterTax,
      grandTotal: grandTotal ?? this.grandTotal,
      onlinePlatformTotal: onlinePlatformTotal ?? this.onlinePlatformTotal,
      platformDifference: platformDifference ?? this.platformDifference,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      catatan: catatan ?? this.catatan,
      cashierId: cashierId ?? this.cashierId,
      cashierNama: cashierNama ?? this.cashierNama,
      isBillPrinted: isBillPrinted ?? this.isBillPrinted,
      billPrintedAt: billPrintedAt ?? this.billPrintedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomor_order': nomorOrder,
      'table_id': tableId,
      'table_nama': tableNama,
      'table_nomor': tableNomor,
      'customer_name': customerName,
      'order_type': orderType,
      'take_away_sub_type': takeAwaySubType,
      'online_platform': onlinePlatform,
      'clear_table_reason': clearTableReason,
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
      'status': status,
      'payment_status': paymentStatus,
      'catatan': catatan,
      'cashier_id': cashierId,
      'cashier_nama': cashierNama,
      'is_bill_printed': isBillPrinted ? 1 : 0,
      'bill_printed_at': billPrintedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawTableId = map['table_id'] as String?;
    final isSentinel = rawTableId == null || rawTableId == 'TABLE_TAKE_AWAY' || rawTableId == 'TAKE_AWAY' || rawTableId.isEmpty;
    return OrderModel(
      id: map['id'] as String,
      nomorOrder: map['nomor_order'] as String,
      tableId: isSentinel ? null : rawTableId,
      tableNama: map['table_nama'] as String?,
      tableNomor: map['table_nomor'] as String?,
      customerName: map['customer_name'] as String?,
      orderType: map['order_type'] as String? ?? 'dine_in',
      takeAwaySubType: map['take_away_sub_type'] as String?,
      onlinePlatform: map['online_platform'] as String?,
      clearTableReason: map['clear_table_reason'] as String?,
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
      status: map['status'] as String,
      paymentStatus: map['payment_status'] as String? ?? 'unpaid',
      catatan: map['catatan'] as String?,
      cashierId: map['cashier_id'] as String?,
      cashierNama: map['cashier_nama'] as String?,
      isBillPrinted: (map['is_bill_printed'] as int?) == 1,
      billPrintedAt: map['bill_printed_at'] != null ? DateTime.parse(map['bill_printed_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
