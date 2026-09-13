import 'package:flutter/material.dart';

class PaymentMethod {
  final String id;
  final String nama;
  final String icon;
  final int aktif; // 1 = active, 0 = inactive
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentMethod({
    required this.id,
    required this.nama,
    required this.icon,
    this.aktif = 1,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => aktif == 1;

  IconData get iconData {
    switch (icon) {
      case 'money':
        return Icons.payments_rounded;
      case 'qr_code':
        return Icons.qr_code_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      default:
        final lowerId = id.toLowerCase();
        if (lowerId.contains('qris')) {
          return Icons.qr_code_rounded;
        } else if (lowerId.contains('tunai')) {
          return Icons.payments_rounded;
        }
        return Icons.credit_card_rounded;
    }
  }

  PaymentMethod copyWith({
    String? id,
    String? nama,
    String? icon,
    int? aktif,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      icon: icon ?? this.icon,
      aktif: aktif ?? this.aktif,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'icon': icon,
      'aktif': aktif,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] as String,
      nama: map['nama'] as String,
      icon: map['icon'] as String,
      aktif: map['aktif'] as int,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
