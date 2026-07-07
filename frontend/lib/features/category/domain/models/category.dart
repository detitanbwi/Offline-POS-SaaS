class Category {
  final String id;
  final String nama;
  final int status; // 1 = aktif, 0 = nonaktif
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.nama,
    this.status = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 1;

  Category copyWith({
    String? id,
    String? nama,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      nama: map['nama'] as String,
      status: map['status'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
