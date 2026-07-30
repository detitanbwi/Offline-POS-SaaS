class OnlinePlatformModel {
  final String id;
  final String nama;
  final String markupType; // 'percentage' or 'nominal'
  final double markupValue;
  final int driverReceiptFormat; // 1 = special large font for driver, 0 = standard
  final int aktif; // 1 = aktif, 0 = nonaktif
  final int isDeleted; // 1 = soft-deleted, 0 = active
  final DateTime createdAt;
  final DateTime updatedAt;

  const OnlinePlatformModel({
    required this.id,
    required this.nama,
    this.markupType = 'percentage',
    this.markupValue = 0.0,
    this.driverReceiptFormat = 1,
    this.aktif = 1,
    this.isDeleted = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => aktif == 1;
  bool get isSoftDeleted => isDeleted == 1;
  bool get useDriverReceiptFormat => driverReceiptFormat == 1;

  double calculateMarkupPrice(double basePrice) {
    if (markupType == 'percentage') {
      return basePrice + (basePrice * (markupValue / 100.0));
    } else {
      return basePrice + markupValue;
    }
  }

  OnlinePlatformModel copyWith({
    String? id,
    String? nama,
    String? markupType,
    double? markupValue,
    int? driverReceiptFormat,
    int? aktif,
    int? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OnlinePlatformModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      markupType: markupType ?? this.markupType,
      markupValue: markupValue ?? this.markupValue,
      driverReceiptFormat: driverReceiptFormat ?? this.driverReceiptFormat,
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
      'markup_type': markupType,
      'markup_value': markupValue,
      'driver_receipt_format': driverReceiptFormat,
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
      markupType: map['markup_type'] as String? ?? 'percentage',
      markupValue: (map['markup_value'] as num?)?.toDouble() ?? 0.0,
      driverReceiptFormat: (map['driver_receipt_format'] as num?)?.toInt() ?? 1,
      aktif: map['aktif'] as int? ?? 1,
      isDeleted: map['is_deleted'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
