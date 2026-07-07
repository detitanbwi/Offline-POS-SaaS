class PaymentMethod {
  final String id;
  final String nama;
  final String icon;
  final int aktif; // 1 = active, 0 = inactive
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentMethod({
    required this.id,
    required this.nama,
    required this.icon,
    this.aktif = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => aktif == 1;

  PaymentMethod copyWith({
    String? id,
    String? nama,
    String? icon,
    int? aktif,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      icon: icon ?? this.icon,
      aktif: aktif ?? this.aktif,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'icon': icon,
      'aktif': aktif,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] as String,
      nama: map['nama'] as String,
      icon: map['icon'] as String,
      aktif: map['aktif'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
