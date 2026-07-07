class PrintBatchModel {
  final String id;
  final String orderId;
  final DateTime createdAt;

  const PrintBatchModel({
    required this.id,
    required this.orderId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PrintBatchModel.fromMap(Map<String, dynamic> map) {
    return PrintBatchModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
