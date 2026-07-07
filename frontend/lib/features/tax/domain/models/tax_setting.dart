class TaxSetting {
  final int id; // Always 1
  final int enable; // 1 = enabled, 0 = disabled
  final double percentage;
  final DateTime updatedAt;

  const TaxSetting({
    this.id = 1,
    this.enable = 0,
    required this.percentage,
    required this.updatedAt,
  });

  bool get isEnabled => enable == 1;

  TaxSetting copyWith({
    int? id,
    int? enable,
    double? percentage,
    DateTime? updatedAt,
  }) {
    return TaxSetting(
      id: id ?? this.id,
      enable: enable ?? this.enable,
      percentage: percentage ?? this.percentage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enable': enable,
      'percentage': percentage,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TaxSetting.fromMap(Map<String, dynamic> map) {
    return TaxSetting(
      id: map['id'] as int,
      enable: map['enable'] as int,
      percentage: (map['percentage'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
