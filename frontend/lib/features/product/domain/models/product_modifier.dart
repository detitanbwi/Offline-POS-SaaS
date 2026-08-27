class ProductModifierOption {
  final String id;
  final String groupId;
  final String nama;
  final double harga;
  final int sortOrder;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModifierOption({
    required this.id,
    required this.groupId,
    required this.nama,
    this.harga = 0.0,
    this.sortOrder = 0,
    this.isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ProductModifierOption copyWith({
    String? id,
    String? groupId,
    String? nama,
    double? harga,
    int? sortOrder,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModifierOption(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      nama: nama ?? this.nama,
      harga: harga ?? this.harga,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'nama': nama,
      'harga': harga,
      'sort_order': sortOrder,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductModifierOption.fromMap(Map<String, dynamic> map) {
    return ProductModifierOption(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      nama: map['nama'] as String,
      harga: (map['harga'] as num?)?.toDouble() ?? 0.0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isDefault: (map['is_default'] as int?) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }
}

class ProductModifierGroup {
  final String id;
  final String productId;
  final String nama;
  final bool isRequired;
  final bool allowMultiple;
  final int minSelect;
  final int maxSelect;
  final int sortOrder;
  final List<ProductModifierOption> options;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModifierGroup({
    required this.id,
    required this.productId,
    required this.nama,
    this.isRequired = false,
    this.allowMultiple = false,
    this.minSelect = 0,
    this.maxSelect = 1,
    this.sortOrder = 0,
    this.options = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ProductModifierGroup copyWith({
    String? id,
    String? productId,
    String? nama,
    bool? isRequired,
    bool? allowMultiple,
    int? minSelect,
    int? maxSelect,
    int? sortOrder,
    List<ProductModifierOption>? options,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModifierGroup(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      nama: nama ?? this.nama,
      isRequired: isRequired ?? this.isRequired,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      minSelect: minSelect ?? this.minSelect,
      maxSelect: maxSelect ?? this.maxSelect,
      sortOrder: sortOrder ?? this.sortOrder,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'nama': nama,
      'is_required': isRequired ? 1 : 0,
      'allow_multiple': allowMultiple ? 1 : 0,
      'min_select': minSelect,
      'max_select': maxSelect,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductModifierGroup.fromMap(Map<String, dynamic> map, {List<ProductModifierOption> options = const []}) {
    return ProductModifierGroup(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      nama: map['nama'] as String,
      isRequired: (map['is_required'] as int?) == 1,
      allowMultiple: (map['allow_multiple'] as int?) == 1,
      minSelect: (map['min_select'] as num?)?.toInt() ?? 0,
      maxSelect: (map['max_select'] as num?)?.toInt() ?? 1,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      options: options,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  bool get isSingleSelect => maxSelect == 1 && !allowMultiple;
}

class SelectedModifier {
  final String groupId;
  final String groupName;
  final String optionId;
  final String optionName;
  final double harga;

  const SelectedModifier({
    required this.groupId,
    required this.groupName,
    required this.optionId,
    required this.optionName,
    required this.harga,
  });

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'option_id': optionId,
      'option_name': optionName,
      'harga': harga,
    };
  }

  factory SelectedModifier.fromMap(Map<String, dynamic> map) {
    return SelectedModifier(
      groupId: map['group_id'] as String? ?? '',
      groupName: map['group_name'] as String? ?? '',
      optionId: map['option_id'] as String? ?? '',
      optionName: map['option_name'] as String? ?? '',
      harga: (map['harga'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedModifier &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          optionId == other.optionId &&
          harga == other.harga;

  @override
  int get hashCode => groupId.hashCode ^ optionId.hashCode ^ harga.hashCode;
}
