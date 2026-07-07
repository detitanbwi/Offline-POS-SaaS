class Product {
  final String id;
  final String kategoriId;
  final String? kategoriNama; // Join field for display
  final String nama;
  final double harga;
  final int stok;
  final int status; // 1 = aktif, 0 = nonaktif
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.kategoriId,
    this.kategoriNama,
    required this.nama,
    required this.harga,
    this.stok = 0,
    this.status = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 1;

  Product copyWith({
    String? id,
    String? kategoriId,
    String? kategoriNama,
    String? nama,
    double? harga,
    int? stok,
    int? status,
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
      status: status ?? this.status,
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
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {String? categoryName}) {
    return Product(
      id: map['id'] as String,
      kategoriId: map['kategori_id'] as String,
      kategoriNama: categoryName ?? map['kategori_nama'] as String?,
      nama: map['nama'] as String,
      harga: (map['harga'] as num).toDouble(),
      stok: map['stok'] as int,
      status: map['status'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
