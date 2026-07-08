class Category {
  final String id;
  final String nama;
  final int status; // 1 = aktif, 0 = nonaktif
  final String? image;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.nama,
    this.status = 1,
    this.image,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 1;

  Category copyWith({
    String? id,
    String? nama,
    int? status,
    String? image,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      status: status ?? this.status,
      image: image ?? this.image,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'status': status,
      'image': image,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      nama: map['nama'] as String,
      status: map['status'] as int,
      image: map['image'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
