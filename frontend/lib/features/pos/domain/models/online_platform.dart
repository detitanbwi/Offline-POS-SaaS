class OnlinePlatformModel {
  final String id;
  final String nama;
  final int aktif; // 1 = aktif, 0 = nonaktif
  final int isDeleted; // 1 = soft-deleted, 0 = active
  final DateTime createdAt;
  final DateTime updatedAt;

  const OnlinePlatformModel({
    required this.id,
    required this.nama,
    this.aktif = 1,
    this.isDeleted = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => aktif == 1;
  bool get isSoftDeleted => isDeleted == 1;

  OnlinePlatformModel copyWith({
    String? id,
    String? nama,
    int? aktif,
    int? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OnlinePlatformModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      aktif: aktif ?? this.aktif,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'aktif': aktif,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory OnlinePlatformModel.fromMap(Map<String, dynamic> map) {
    return OnlinePlatformModel(
      id: map['id'] as String,
      nama: map['nama'] as String,
      aktif: map['aktif'] as int,
      isDeleted: map['is_deleted'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
