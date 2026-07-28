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
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancelledReason;
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
    this.isCancelled = false,
    this.cancelledAt,
    this.cancelledReason,
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
    bool? isCancelled,
    DateTime? cancelledAt,
    String? cancelledReason,
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
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
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
      'is_cancelled': isCancelled ? 1 : 0,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancelled_reason': cancelledReason,
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
      isCancelled: (map['is_cancelled'] as int?) == 1,
      cancelledAt: map['cancelled_at'] != null ? DateTime.parse(map['cancelled_at'] as String) : null,
      cancelledReason: map['cancelled_reason'] as String?,
      printBatchId: map['print_batch_id'] as String?,
    );
  }
}
