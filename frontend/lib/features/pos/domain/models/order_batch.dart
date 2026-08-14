class OrderBatchModel {
  final String id;
  final String masterOrderId;
  final int batchNumber; // 1 = initial order, 2 = add-on round 1, etc.
  final String? createdByCashierId;
  final String paymentStatus; // 'unpaid', 'paid'
  final DateTime createdAt;

  const OrderBatchModel({
    required this.id,
    required this.masterOrderId,
    required this.batchNumber,
    this.createdByCashierId,
    this.paymentStatus = 'unpaid',
    required this.createdAt,
  });

  OrderBatchModel copyWith({
    String? id,
    String? masterOrderId,
    int? batchNumber,
    String? createdByCashierId,
    String? paymentStatus,
    DateTime? createdAt,
  }) {
    return OrderBatchModel(
      id: id ?? this.id,
      masterOrderId: masterOrderId ?? this.masterOrderId,
      batchNumber: batchNumber ?? this.batchNumber,
      createdByCashierId: createdByCashierId ?? this.createdByCashierId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'master_order_id': masterOrderId,
      'batch_number': batchNumber,
      'created_by_cashier_id': createdByCashierId,
      'payment_status': paymentStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OrderBatchModel.fromMap(Map<String, dynamic> map) {
    return OrderBatchModel(
      id: map['id'] as String,
      masterOrderId: map['master_order_id'] as String,
      batchNumber: (map['batch_number'] as num).toInt(),
      createdByCashierId: map['created_by_cashier_id'] as String?,
      paymentStatus: map['payment_status'] as String? ?? 'unpaid',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
