class PackageItem {
  final String id;
  final String packageId;
  final String productId;
  final String? productNama;
  final double? productHarga;
  final int? productStok;
  final String? kategoriId;
  final String? kategoriNama;
  final int qty;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PackageItem({
    required this.id,
    required this.packageId,
    required this.productId,
    this.productNama,
    this.productHarga,
    this.productStok,
    this.kategoriId,
    this.kategoriNama,
    required this.qty,
    required this.createdAt,
    required this.updatedAt,
  });

  PackageItem copyWith({
    String? id,
    String? packageId,
    String? productId,
    String? productNama,
    double? productHarga,
    int? productStok,
    String? kategoriId,
    String? kategoriNama,
    int? qty,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PackageItem(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      productId: productId ?? this.productId,
      productNama: productNama ?? this.productNama,
      productHarga: productHarga ?? this.productHarga,
      productStok: productStok ?? this.productStok,
      kategoriId: kategoriId ?? this.kategoriId,
      kategoriNama: kategoriNama ?? this.kategoriNama,
      qty: qty ?? this.qty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_id': packageId,
      'product_id': productId,
      'qty': qty,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PackageItem.fromMap(Map<String, dynamic> map, {
    String? productName,
    double? productPrice,
    int? productStock,
    String? categoryId,
    String? categoryName,
  }) {
    return PackageItem(
      id: map['id'] as String,
      packageId: map['package_id'] as String,
      productId: map['product_id'] as String,
      productNama: productName ?? map['product_nama'] as String?,
      productHarga: productPrice ?? (map['product_harga'] != null ? (map['product_harga'] as num).toDouble() : null),
      productStok: productStock ?? (map['product_stok'] as int?),
      kategoriId: categoryId ?? map['kategori_id'] as String?,
      kategoriNama: categoryName ?? map['kategori_nama'] as String?,
      qty: (map['qty'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
