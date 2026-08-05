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
  final double taxPercentage;
  final double taxAmount;
  final double grandTotal;
  final double? onlinePlatformTotal;
  final double? platformDifference;
  final String status; // 'draft', 'completed', 'cancelled'
  final String? catatan;
  final String? cashierId;
  final String? cashierNama;
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
    this.taxPercentage = 0.0,
    this.taxAmount = 0.0,
    this.grandTotal = 0.0,
    this.onlinePlatformTotal,
    this.platformDifference,
    this.status = 'draft',
    this.catatan,
    this.cashierId,
    this.cashierNama,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status == 'draft';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isTakeAway => orderType == 'take_away';

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
    double? taxPercentage,
    double? taxAmount,
    double? grandTotal,
    double? onlinePlatformTotal,
    double? platformDifference,
    String? status,
    String? catatan,
    String? cashierId,
    String? cashierNama,
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
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      onlinePlatformTotal: onlinePlatformTotal ?? this.onlinePlatformTotal,
      platformDifference: platformDifference ?? this.platformDifference,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      cashierId: cashierId ?? this.cashierId,
      cashierNama: cashierNama ?? this.cashierNama,
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
      'tax_percentage': taxPercentage,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'online_platform_total': onlinePlatformTotal,
      'platform_difference': platformDifference,
      'status': status,
      'catatan': catatan,
      'cashier_id': cashierId,
      'cashier_nama': cashierNama,
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
      taxPercentage: (map['tax_percentage'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      onlinePlatformTotal: (map['online_platform_total'] as num?)?.toDouble(),
      platformDifference: (map['platform_difference'] as num?)?.toDouble(),
      status: map['status'] as String,
      catatan: map['catatan'] as String?,
      cashierId: map['cashier_id'] as String?,
      cashierNama: map['cashier_nama'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
