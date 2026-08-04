class CashierModel {
  final String id;
  final String nama;
  final String username;
  final String pin; // hashed
  final int status; // 1 = active, 0 = inactive
  final int isDeleted; // 1 = soft-deleted, 0 = active
  final int isOwner; // 1 = owner, 0 = standard cashier
  final DateTime createdAt;
  final DateTime updatedAt;

  const CashierModel({
    required this.id,
    required this.nama,
    required this.username,
    required this.pin,
    this.status = 1,
    this.isDeleted = 0,
    this.isOwner = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 1;
  bool get isSoftDeleted => isDeleted == 1;
  bool get isOwnerCashier => isOwner == 1;

  CashierModel copyWith({
    String? id,
    String? nama,
    String? username,
    String? pin,
    int? status,
    int? isDeleted,
    int? isOwner,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashierModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      username: username ?? this.username,
      pin: pin ?? this.pin,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      isOwner: isOwner ?? this.isOwner,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'username': username,
      'pin': pin,
      'status': status,
      'is_deleted': isDeleted,
      'is_owner': isOwner,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CashierModel.fromMap(Map<String, dynamic> map) {
    final rawName = map['nama'] as String? ?? '';
    final rawUsername = map['username'] as String?;
    return CashierModel(
      id: map['id'] as String,
      nama: rawName,
      username: rawUsername != null && rawUsername.isNotEmpty
          ? rawUsername
          : rawName.toLowerCase().replaceAll(' ', '_'),
      pin: map['pin'] as String,
      status: map['status'] as int,
      isDeleted: map['is_deleted'] as int,
      isOwner: map['is_owner'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

