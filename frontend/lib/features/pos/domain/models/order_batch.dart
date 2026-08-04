class OrderBatchModel {
  final String id;
  final String masterOrderId;
  final int batchNumber; // 1 = initial order, 2 = add-on round 1, etc.
  final String? createdByCashierId;
  final DateTime createdAt;

  const OrderBatchModel({
    required this.id,
    required this.masterOrderId,
    required this.batchNumber,
    this.createdByCashierId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'master_order_id': masterOrderId,
      'batch_number': batchNumber,
      'created_by_cashier_id': createdByCashierId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OrderBatchModel.fromMap(Map<String, dynamic> map) {
    return OrderBatchModel(
      id: map['id'] as String,
      masterOrderId: map['master_order_id'] as String,
      batchNumber: (map['batch_number'] as num).toInt(),
      createdByCashierId: map['created_by_cashier_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
