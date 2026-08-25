class TaxSetting {
  final int id; // Always 1
  final int enable; // 1 = enabled, 0 = disabled
  final double percentage;
  final int serviceChargeEnable; // 1 = enabled, 0 = disabled
  final double serviceChargePercentage;
  final int serviceChargeAfterTax; // 1 = compound after tax, 0 = standard before tax
  final DateTime updatedAt;

  const TaxSetting({
    this.id = 1,
    this.enable = 0,
    required this.percentage,
    this.serviceChargeEnable = 0,
    this.serviceChargePercentage = 0.0,
    this.serviceChargeAfterTax = 0,
    required this.updatedAt,
  });

  bool get isEnabled => enable == 1;
  bool get isServiceChargeEnabled => serviceChargeEnable == 1;
  bool get isServiceChargeAfterTax => serviceChargeAfterTax == 1;

  TaxSetting copyWith({
    int? id,
    int? enable,
    double? percentage,
    int? serviceChargeEnable,
    double? serviceChargePercentage,
    int? serviceChargeAfterTax,
    DateTime? updatedAt,
  }) {
    return TaxSetting(
      id: id ?? this.id,
      enable: enable ?? this.enable,
      percentage: percentage ?? this.percentage,
      serviceChargeEnable: serviceChargeEnable ?? this.serviceChargeEnable,
      serviceChargePercentage: serviceChargePercentage ?? this.serviceChargePercentage,
      serviceChargeAfterTax: serviceChargeAfterTax ?? this.serviceChargeAfterTax,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enable': enable,
      'percentage': percentage,
      'service_charge_enable': serviceChargeEnable,
      'service_charge_percentage': serviceChargePercentage,
      'service_charge_after_tax': serviceChargeAfterTax,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TaxSetting.fromMap(Map<String, dynamic> map) {
    return TaxSetting(
      id: (map['id'] as int?) ?? 1,
      enable: (map['enable'] as int?) ?? 0,
      percentage: ((map['percentage'] as num?) ?? 0.0).toDouble(),
      serviceChargeEnable: (map['service_charge_enable'] as int?) ?? 0,
      serviceChargePercentage: ((map['service_charge_percentage'] as num?) ?? 0.0).toDouble(),
      serviceChargeAfterTax: (map['service_charge_after_tax'] as int?) ?? 0,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }
}
