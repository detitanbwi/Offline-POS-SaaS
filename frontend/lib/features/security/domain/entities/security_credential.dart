/// Domain Entity representing the isolated License & Security credentials domain.
/// Adheres to Domain-Driven Design (DDD) principles and Clean Architecture.
class SecurityCredential {
  final String id;
  final String masterPinHash;
  final String recoveryCodeHash;
  final String licenseKeyLastSix;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SecurityCredential({
    required this.id,
    required this.masterPinHash,
    required this.recoveryCodeHash,
    required this.licenseKeyLastSix,
    required this.createdAt,
    required this.updatedAt,
  });

  SecurityCredential copyWith({
    String? id,
    String? masterPinHash,
    String? recoveryCodeHash,
    String? licenseKeyLastSix,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SecurityCredential(
      id: id ?? this.id,
      masterPinHash: masterPinHash ?? this.masterPinHash,
      recoveryCodeHash: recoveryCodeHash ?? this.recoveryCodeHash,
      licenseKeyLastSix: licenseKeyLastSix ?? this.licenseKeyLastSix,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'master_pin_hash': masterPinHash,
      'recovery_code_hash': recoveryCodeHash,
      'license_key_last_six': licenseKeyLastSix,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SecurityCredential.fromMap(Map<String, dynamic> map) {
    return SecurityCredential(
      id: map['id'] as String? ?? 'master_security_core',
      masterPinHash: map['master_pin_hash'] as String? ?? '',
      recoveryCodeHash: map['recovery_code_hash'] as String? ?? '',
      licenseKeyLastSix: map['license_key_last_six'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
