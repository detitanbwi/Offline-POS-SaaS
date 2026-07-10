class TransactionHeader {
  final String id;
  final String nomorTransaksi;
  final double subtotal;
  final double taxPercentage;
  final double taxAmount;
  final double grandTotal;
  final String paymentMethodId;
  final String paymentMethodNama;
  final double nominalBayar;
  final double kembalian;
  final String? catatan;
  final String status; // 'completed', 'cancelled', 'voided'
  final DateTime createdAt;
  final String? cashierId;
  final String? cashierNama;

  const TransactionHeader({
    required this.id,
    required this.nomorTransaksi,
    required this.subtotal,
    required this.taxPercentage,
    required this.taxAmount,
    required this.grandTotal,
    required this.paymentMethodId,
    required this.paymentMethodNama,
    required this.nominalBayar,
    required this.kembalian,
    this.catatan,
    this.status = 'completed',
    required this.createdAt,
    this.cashierId,
    this.cashierNama,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomor_transaksi': nomorTransaksi,
      'subtotal': subtotal,
      'tax_percentage': taxPercentage,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'payment_method_id': paymentMethodId,
      'payment_method_nama': paymentMethodNama,
      'nominal_bayar': nominalBayar,
      'kembalian': kembalian,
      'catatan': catatan,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'cashier_id': cashierId,
      'cashier_nama': cashierNama,
    };
  }

  factory TransactionHeader.fromMap(Map<String, dynamic> map) {
    return TransactionHeader(
      id: map['id'] as String,
      nomorTransaksi: map['nomor_transaksi'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      taxPercentage: (map['tax_percentage'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      paymentMethodId: map['payment_method_id'] as String,
      paymentMethodNama: map['payment_method_nama'] as String,
      nominalBayar: (map['nominal_bayar'] as num).toDouble(),
      kembalian: (map['kembalian'] as num).toDouble(),
      catatan: map['catatan'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      cashierId: map['cashier_id'] as String?,
      cashierNama: map['cashier_nama'] as String?,
    );
  }
}

class TransactionItem {
  final String id;
  final String transactionId;
  final String produkId;
  final String produkNama;
  final double produkHarga;
  final int qty;
  final double subtotal;
  final String? catatan;

  const TransactionItem({
    required this.id,
    required this.transactionId,
    required this.produkId,
    required this.produkNama,
    required this.produkHarga,
    required this.qty,
    required this.subtotal,
    this.catatan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'produk_id': produkId,
      'produk_nama': produkNama,
      'produk_harga': produkHarga,
      'qty': qty,
      'subtotal': subtotal,
      'catatan': catatan,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      produkId: map['produk_id'] as String,
      produkNama: map['produk_nama'] as String,
      produkHarga: (map['produk_harga'] as num).toDouble(),
      qty: map['qty'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      catatan: map['catatan'] as String?,
    );
  }
}
