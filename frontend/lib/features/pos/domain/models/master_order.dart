class MasterOrderModel {
  final String id;
  final String nomorOrder;
  final String? tableId;
  final String? customerName;
  final String orderType; // 'dine_in_prepaid', 'dine_in_postpaid', 'takeaway_walkin', 'takeaway_online'
  final String? platformId;
  final String? platformReferenceId;
  final double subtotal;
  final double taxPercentage;
  final double taxAmount;
  final double grandTotal;
  final double totalPaid;
  final String sessionStatus; // 'open', 'settled', 'cancelled'
  final String paymentStatus; // 'unpaid', 'partially_paid', 'paid'
  final DateTime lastActivityAt;
  final DateTime? allItemsServedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MasterOrderModel({
    required this.id,
    required this.nomorOrder,
    this.tableId,
    this.customerName,
    required this.orderType,
    this.platformId,
    this.platformReferenceId,
    this.subtotal = 0.0,
    this.taxPercentage = 0.0,
    this.taxAmount = 0.0,
    this.grandTotal = 0.0,
    this.totalPaid = 0.0,
    this.sessionStatus = 'open',
    this.paymentStatus = 'unpaid',
    required this.lastActivityAt,
    this.allItemsServedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => sessionStatus == 'open';
  bool get isSettled => sessionStatus == 'settled';
  bool get isCancelled => sessionStatus == 'cancelled';
  bool get isPaid => paymentStatus == 'paid';
  bool get isUnpaid => paymentStatus == 'unpaid';
  bool get isPartiallyPaid => paymentStatus == 'partially_paid';
  double get remainingBalance => grandTotal - totalPaid;
  bool get isOnlineFood => orderType == 'takeaway_online';
  bool get isDineIn => orderType.startsWith('dine_in');

  MasterOrderModel copyWith({
    String? id,
    String? nomorOrder,
    String? tableId,
    String? customerName,
    String? orderType,
    String? platformId,
    String? platformReferenceId,
    double? subtotal,
    double? taxPercentage,
    double? taxAmount,
    double? grandTotal,
    double? totalPaid,
    String? sessionStatus,
    String? paymentStatus,
    DateTime? lastActivityAt,
    DateTime? allItemsServedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MasterOrderModel(
      id: id ?? this.id,
      nomorOrder: nomorOrder ?? this.nomorOrder,
      tableId: tableId ?? this.tableId,
      customerName: customerName ?? this.customerName,
      orderType: orderType ?? this.orderType,
      platformId: platformId ?? this.platformId,
      platformReferenceId: platformReferenceId ?? this.platformReferenceId,
      subtotal: subtotal ?? this.subtotal,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      totalPaid: totalPaid ?? this.totalPaid,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      allItemsServedAt: allItemsServedAt ?? this.allItemsServedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomor_order': nomorOrder,
      'table_id': tableId,
      'customer_name': customerName,
      'order_type': orderType,
      'platform_id': platformId,
      'platform_reference_id': platformReferenceId,
      'subtotal': subtotal,
      'tax_percentage': taxPercentage,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'total_paid': totalPaid,
      'session_status': sessionStatus,
      'payment_status': paymentStatus,
      'last_activity_at': lastActivityAt.toIso8601String(),
      'all_items_served_at': allItemsServedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MasterOrderModel.fromMap(Map<String, dynamic> map) {
    return MasterOrderModel(
      id: map['id'] as String,
      nomorOrder: map['nomor_order'] as String,
      tableId: map['table_id'] as String?,
      customerName: map['customer_name'] as String?,
      orderType: map['order_type'] as String? ?? 'dine_in_postpaid',
      platformId: map['platform_id'] as String?,
      platformReferenceId: map['platform_reference_id'] as String?,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxPercentage: (map['tax_percentage'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0.0,
      sessionStatus: map['session_status'] as String? ?? 'open',
      paymentStatus: map['payment_status'] as String? ?? 'unpaid',
      lastActivityAt: map['last_activity_at'] != null
          ? DateTime.parse(map['last_activity_at'] as String)
          : DateTime.now(),
      allItemsServedAt: map['all_items_served_at'] != null
          ? DateTime.parse(map['all_items_served_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
