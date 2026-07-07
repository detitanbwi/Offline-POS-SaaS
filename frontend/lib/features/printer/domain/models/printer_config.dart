class PrinterConfigModel {
  final String id;
  final String name;
  final String address;
  final String type; // 'cashier' or 'kitchen'
  final bool isConnected;
  final DateTime createdAt;

  const PrinterConfigModel({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    this.isConnected = false,
    required this.createdAt,
  });

  bool get isCashier => type == 'cashier';
  bool get isKitchen => type == 'kitchen';

  PrinterConfigModel copyWith({
    String? id,
    String? name,
    String? address,
    String? type,
    bool? isConnected,
    DateTime? createdAt,
  }) {
    return PrinterConfigModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'type': type,
      'is_connected': isConnected ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PrinterConfigModel.fromMap(Map<String, dynamic> map) {
    return PrinterConfigModel(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      type: map['type'] as String,
      isConnected: (map['is_connected'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
