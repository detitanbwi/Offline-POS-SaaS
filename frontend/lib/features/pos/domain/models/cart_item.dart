import '../../../product/domain/models/product.dart';

class CartItem {
  final Product product;
  final int qty;
  final String catatan;
  final int initialSavedQty;
  final String? batchId;
  final bool isBilled;
  final String? batchName;

  const CartItem({
    required this.product,
    required this.qty,
    this.catatan = '',
    this.initialSavedQty = 0,
    this.batchId,
    this.isBilled = false,
    this.batchName,
  });

  double get subtotal => product.harga * qty;
  bool get canDecrement => qty > initialSavedQty;

  CartItem copyWith({
    Product? product,
    int? qty,
    String? catatan,
    int? initialSavedQty,
    String? batchId,
    bool? isBilled,
    String? batchName,
  }) {
    return CartItem(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      catatan: catatan ?? this.catatan,
      initialSavedQty: initialSavedQty ?? this.initialSavedQty,
      batchId: batchId ?? this.batchId,
      isBilled: isBilled ?? this.isBilled,
      batchName: batchName ?? this.batchName,
    );
  }
}
