import '../../../product/domain/models/product.dart';

class CartItem {
  final Product product;
  final int qty;
  final String catatan;

  const CartItem({
    required this.product,
    required this.qty,
    this.catatan = '',
  });

  double get subtotal => product.harga * qty;

  CartItem copyWith({
    Product? product,
    int? qty,
    String? catatan,
  }) {
    return CartItem(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      catatan: catatan ?? this.catatan,
    );
  }
}
