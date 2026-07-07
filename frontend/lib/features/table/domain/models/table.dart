class TableModel {
  final String id;
  final String nama;
  final String nomor;
  final int status; // 0: Kosong, 1: Terisi, 2: Reserved, 3: Maintenance
  final DateTime createdAt;
  final DateTime updatedAt;

  const TableModel({
    required this.id,
    required this.nama,
    required this.nomor,
    this.status = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEmpty => status == 0;
  bool get isOccupied => status == 1;
  bool get isReserved => status == 2;
  bool get isMaintenance => status == 3;

  String get statusLabel {
    switch (status) {
      case 0:
        return 'Kosong';
      case 1:
        return 'Terisi';
      case 2:
        return 'Reserved';
      case 3:
        return 'Maintenance';
      default:
        return 'Unknown';
    }
  }

  TableModel copyWith({
    String? id,
    String? nama,
    String? nomor,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TableModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      nomor: nomor ?? this.nomor,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'nomor': nomor,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      id: map['id'] as String,
      nama: map['nama'] as String,
      nomor: map['nomor'] as String,
      status: map['status'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
