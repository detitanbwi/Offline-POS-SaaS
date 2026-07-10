class CashierModel {
  final String id;
  final String nama;
  final String pin; // hashed
  final int status; // 1 = active, 0 = inactive
  final int isDeleted; // 1 = soft-deleted, 0 = active
  final DateTime createdAt;
  final DateTime updatedAt;

  const CashierModel({
    required this.id,
    required this.nama,
    required this.pin,
    this.status = 1,
    this.isDeleted = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 1;
  bool get isSoftDeleted => isDeleted == 1;

  CashierModel copyWith({
    String? id,
    String? nama,
    String? pin,
    int? status,
    int? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashierModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      pin: pin ?? this.pin,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'pin': pin,
      'status': status,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CashierModel.fromMap(Map<String, dynamic> map) {
    return CashierModel(
      id: map['id'] as String,
      nama: map['nama'] as String,
      pin: map['pin'] as String,
      status: map['status'] as int,
      isDeleted: map['is_deleted'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
