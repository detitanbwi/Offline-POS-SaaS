class OrderItemModel {
  final String id;
  final String orderId;
  final String produkId;
  final String produkNama;
  final double produkHarga;
  final int qty;
  final double subtotal;
  final String? catatan;
  final int statusCetak; // 0: Belum Dicetak, 1: Sudah Dicetak
  final String? printBatchId;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.produkId,
    required this.produkNama,
    required this.produkHarga,
    required this.qty,
    required this.subtotal,
    this.catatan,
    this.statusCetak = 0,
    this.printBatchId,
  });

  bool get isPrinted => statusCetak == 1;

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? produkId,
    String? produkNama,
    double? produkHarga,
    int? qty,
    double? subtotal,
    String? catatan,
    int? statusCetak,
    String? printBatchId,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      produkId: produkId ?? this.produkId,
      produkNama: produkNama ?? this.produkNama,
      produkHarga: produkHarga ?? this.produkHarga,
      qty: qty ?? this.qty,
      subtotal: subtotal ?? this.subtotal,
      catatan: catatan ?? this.catatan,
      statusCetak: statusCetak ?? this.statusCetak,
      printBatchId: printBatchId ?? this.printBatchId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'produk_id': produkId,
      'produk_nama': produkNama,
      'produk_harga': produkHarga,
      'qty': qty,
      'subtotal': subtotal,
      'catatan': catatan,
      'status_cetak': statusCetak,
      'print_batch_id': printBatchId,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      produkId: map['produk_id'] as String,
      produkNama: map['produk_nama'] as String,
      produkHarga: (map['produk_harga'] as num).toDouble(),
      qty: map['qty'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      catatan: map['catatan'] as String?,
      statusCetak: map['status_cetak'] as int,
      printBatchId: map['print_batch_id'] as String?,
    );
  }
}
