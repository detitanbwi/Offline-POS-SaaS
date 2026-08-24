export 'package_item.dart';
import 'package_item.dart';

class Product {
  final String id;
  final String kategoriId;
  final String? kategoriNama; // Join field for display
  final String nama;
  final double harga;
  final int stok;
  final bool isPackage;
  final List<PackageItem> packageItems;
  final int status; // 1 = aktif, 0 = nonaktif
  final String? image;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.kategoriId,
    this.kategoriNama,
    required this.nama,
    required this.harga,
    this.stok = 0,
    this.isPackage = false,
    this.packageItems = const [],
    this.status = 1,
    this.image,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 1;

  /// Calculates effective available stock.
  /// If [isPackage] is true, computes: min(floor(component.stok / item.qty))
  /// for all stock-tracked components.
  int getEffectiveStock({List<Product>? allProducts}) {
    if (!isPackage) {
      return stok;
    }

    if (packageItems.isEmpty) {
      return 0;
    }

    // Map existing products by ID for fast lookup if allProducts is provided
    final productMap = allProducts != null
        ? {for (var p in allProducts) p.id: p}
        : null;

    int minAvailable = -1; // -1 means unlimited / always available

    for (var item in packageItems) {
      final compProduct = productMap != null ? productMap[item.productId] : null;
      final compStock = compProduct?.stok ?? item.productStok ?? -1;

      if (compStock == -1) {
        // Non-stock item, doesn't constrain package stock
        continue;
      }

      if (compStock <= 0 || item.qty <= 0) {
        return 0; // Out of stock
      }

      final possibleSets = compStock ~/ item.qty;
      if (minAvailable == -1 || possibleSets < minAvailable) {
        minAvailable = possibleSets;
      }
    }

    return minAvailable;
  }

  Product copyWith({
    String? id,
    String? kategoriId,
    String? kategoriNama,
    String? nama,
    double? harga,
    int? stok,
    bool? isPackage,
    List<PackageItem>? packageItems,
    int? status,
    String? image,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      kategoriId: kategoriId ?? this.kategoriId,
      kategoriNama: kategoriNama ?? this.kategoriNama,
      nama: nama ?? this.nama,
      harga: harga ?? this.harga,
      stok: stok ?? this.stok,
      isPackage: isPackage ?? this.isPackage,
      packageItems: packageItems ?? this.packageItems,
      status: status ?? this.status,
      image: image ?? this.image,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kategori_id': kategoriId,
      'nama': nama,
      'harga': harga,
      'stok': stok,
      'is_package': isPackage ? 1 : 0,
      'status': status,
      'image': image,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(
    Map<String, dynamic> map, {
    String? categoryName,
    List<PackageItem>? packageItems,
  }) {
    return Product(
      id: map['id'] as String,
      kategoriId: map['kategori_id'] as String,
      kategoriNama: categoryName ?? map['kategori_nama'] as String?,
      nama: map['nama'] as String,
      harga: (map['harga'] as num).toDouble(),
      stok: map['stok'] as int,
      isPackage: (map['is_package'] as int? ?? 0) == 1,
      packageItems: packageItems ?? const [],
      status: map['status'] as int,
      image: map['image'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
