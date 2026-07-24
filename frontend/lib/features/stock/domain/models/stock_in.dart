class StockIn {
  final String id;
  final String produkId;
  final String? produkNama; // Join field for display
  final String type; // 'in' or 'out'
  final int qty;
  final String tanggal; // ISO8601 String
  final String? catatan;
  final DateTime createdAt;

  const StockIn({
    required this.id,
    required this.produkId,
    this.produkNama,
    this.type = 'in',
    required this.qty,
    required this.tanggal,
    this.catatan,
    required this.createdAt,
  });

  bool get isOut => type == 'out' || qty < 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'produk_id': produkId,
      'type': type,
      'qty': qty,
      'tanggal': tanggal,
      'catatan': catatan,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StockIn.fromMap(Map<String, dynamic> map, {String? productName}) {
    return StockIn(
      id: map['id'] as String,
      produkId: map['produk_id'] as String,
      produkNama: productName ?? map['produk_nama'] as String?,
      type: (map['type'] as String?) ?? 'in',
      qty: map['qty'] as int,
      tanggal: map['tanggal'] as String,
      catatan: map['catatan'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
