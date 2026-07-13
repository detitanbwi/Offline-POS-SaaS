import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../product/domain/models/product.dart';
import '../domain/models/cart_item.dart';
import '../domain/models/order_item.dart';
import '../../tax/application/tax_notifier.dart';

class CartState {
  final List<CartItem> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double grandTotal;
  final String? errorMessage;

  CartState({
    this.items = const [],
    this.subtotal = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.grandTotal = 0.0,
    this.errorMessage,
  });

  CartState copyWith({
    List<CartItem>? items,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? grandTotal,
    String? errorMessage,
  }) {
    return CartState(
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      errorMessage: errorMessage,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final Ref _ref;

  CartNotifier(this._ref) : super(CartState()) {
    // Listen to tax settings changes to auto-recalculate totals
    _ref.listen(taxNotifierProvider, (previous, next) {
      _recalculate();
    });
  }

  void _recalculate({List<CartItem>? currentItems}) {
    final activeItems = currentItems ?? state.items;
    double sub = 0.0;
    for (var item in activeItems) {
      sub += item.subtotal;
    }

    final taxState = _ref.read(taxNotifierProvider);
    double rate = 0.0;
    if (taxState.taxSetting != null && taxState.taxSetting!.isEnabled) {
      rate = taxState.taxSetting!.percentage;
    }

    double tax = sub * (rate / 100);
    double grand = sub + tax;

    state = state.copyWith(
      items: activeItems,
      subtotal: sub,
      taxRate: rate,
      taxAmount: tax,
      grandTotal: grand,
      errorMessage: null,
    );
  }

  bool addItem(Product product) {
    if (!product.isActive) {
      state = state.copyWith(errorMessage: 'Produk tidak aktif');
      return false;
    }
    if (product.stok != -1 && product.stok <= 0) {
      state = state.copyWith(errorMessage: 'Stok "${product.nama}" habis!');
      return false;
    }

    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);
    List<CartItem> updatedItems = List.from(state.items);

    if (existingIndex != -1) {
      final currentQty = state.items[existingIndex].qty;
      if (product.stok != -1 && currentQty >= product.stok) {
        state = state.copyWith(errorMessage: 'Stok "${product.nama}" tidak mencukupi!');
        return false;
      }
      updatedItems[existingIndex] = state.items[existingIndex].copyWith(
        qty: currentQty + 1,
      );
    } else {
      updatedItems.add(CartItem(product: product, qty: 1));
    }

    _recalculate(currentItems: updatedItems);
    return true;
  }

  void removeItem(String productId) {
    final updatedItems = state.items.where((item) => item.product.id != productId).toList();
    _recalculate(currentItems: updatedItems);
  }

  bool updateQuantity(String productId, int newQty) {
    if (newQty <= 0) {
      removeItem(productId);
      return true;
    }

    final index = state.items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return false;

    final product = state.items[index].product;
    if (product.stok != -1 && newQty > product.stok) {
      state = state.copyWith(errorMessage: 'Stok "${product.nama}" tidak mencukupi (Maks: ${product.stok})');
      return false;
    }

    List<CartItem> updatedItems = List.from(state.items);
    updatedItems[index] = state.items[index].copyWith(qty: newQty);

    _recalculate(currentItems: updatedItems);
    return true;
  }

  void updateCatatan(String productId, String catatan) {
    final index = state.items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;

    List<CartItem> updatedItems = List.from(state.items);
    updatedItems[index] = state.items[index].copyWith(catatan: catatan);

    _recalculate(currentItems: updatedItems);
  }

  void loadDraftItems(List<OrderItemModel> draftItems, List<Product> allProducts) {
    final List<CartItem> loaded = [];
    for (var draft in draftItems) {
      final productIndex = allProducts.indexWhere((p) => p.id == draft.produkId);
      if (productIndex != -1) {
        final product = allProducts[productIndex];
        loaded.add(CartItem(
          product: product,
          qty: draft.qty,
          catatan: draft.catatan ?? '',
        ));
      }
    }
    _recalculate(currentItems: loaded);
  }

  void clear() {
    state = CartState();
  }
}

final cartNotifierProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});
