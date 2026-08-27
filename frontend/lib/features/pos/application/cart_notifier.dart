import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../product/domain/models/product.dart';
import '../../product/application/product_notifier.dart';
import '../domain/models/cart_item.dart';
import '../domain/models/order_item.dart';
import '../domain/models/print_batch.dart';
import '../../tax/application/tax_notifier.dart';
import 'order_notifier.dart';

class CartState {
  final List<CartItem> items;
  final double grossSubtotal;
  final double itemDiscountTotal;
  final double subtotal; // items grossSubtotal - itemDiscountTotal
  final double orderDiscountRate;
  final double orderDiscountAmount;
  final String orderDiscountType; // 'percent' or 'nominal'
  final double netSubtotal; // subtotal - orderDiscountAmount
  final double taxRate;
  final double taxAmount;
  final double serviceChargeRate;
  final double serviceChargeAmount;
  final bool serviceChargeAfterTax;
  final double grandTotal;
  final String? errorMessage;

  CartState({
    this.items = const [],
    this.grossSubtotal = 0.0,
    this.itemDiscountTotal = 0.0,
    this.subtotal = 0.0,
    this.orderDiscountRate = 0.0,
    this.orderDiscountAmount = 0.0,
    this.orderDiscountType = 'percent',
    this.netSubtotal = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.serviceChargeRate = 0.0,
    this.serviceChargeAmount = 0.0,
    this.serviceChargeAfterTax = false,
    this.grandTotal = 0.0,
    this.errorMessage,
  });

  bool get hasDiscount => itemDiscountTotal > 0 || orderDiscountAmount > 0;
  double get totalDiscount => itemDiscountTotal + orderDiscountAmount;

  CartState copyWith({
    List<CartItem>? items,
    double? grossSubtotal,
    double? itemDiscountTotal,
    double? subtotal,
    double? orderDiscountRate,
    double? orderDiscountAmount,
    String? orderDiscountType,
    double? netSubtotal,
    double? taxRate,
    double? taxAmount,
    double? serviceChargeRate,
    double? serviceChargeAmount,
    bool? serviceChargeAfterTax,
    double? grandTotal,
    String? errorMessage,
  }) {
    return CartState(
      items: items ?? this.items,
      grossSubtotal: grossSubtotal ?? this.grossSubtotal,
      itemDiscountTotal: itemDiscountTotal ?? this.itemDiscountTotal,
      subtotal: subtotal ?? this.subtotal,
      orderDiscountRate: orderDiscountRate ?? this.orderDiscountRate,
      orderDiscountAmount: orderDiscountAmount ?? this.orderDiscountAmount,
      orderDiscountType: orderDiscountType ?? this.orderDiscountType,
      netSubtotal: netSubtotal ?? this.netSubtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
      serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
      serviceChargeAfterTax: serviceChargeAfterTax ?? this.serviceChargeAfterTax,
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

    // Listen to order type / platform changes to auto-recalculate totals
    _ref.listen(orderNotifierProvider, (previous, next) {
      if (previous?.orderType != next.orderType ||
          previous?.takeAwaySubType != next.takeAwaySubType ||
          previous?.onlinePlatform != next.onlinePlatform) {
        _recalculate();
      }
    });
  }

  void recalculateTotals() {
    _recalculate();
  }

  void _recalculate({
    List<CartItem>? currentItems,
    double? orderDiscountRate,
    double? orderDiscountAmount,
    String? orderDiscountType,
  }) {
    final activeItems = currentItems ?? state.items;

    double grossSub = 0.0;
    double itemDiscTotal = 0.0;
    double itemsSub = 0.0;

    for (var item in activeItems) {
      grossSub += item.grossSubtotal;
      itemDiscTotal += item.discountAmount;
      itemsSub += item.subtotal;
    }

    // Determine order discount
    String ordDiscType = orderDiscountType ?? state.orderDiscountType;
    double ordDiscRate = orderDiscountRate ?? state.orderDiscountRate;
    double ordDiscAmount = orderDiscountAmount ?? state.orderDiscountAmount;

    if (ordDiscType == 'percent') {
      if (ordDiscRate <= 0) {
        ordDiscRate = 0.0;
        ordDiscAmount = 0.0;
      } else {
        ordDiscRate = ordDiscRate.clamp(0.0, 100.0);
        ordDiscAmount = (itemsSub * (ordDiscRate / 100)).clamp(0.0, itemsSub);
      }
    } else {
      if (ordDiscAmount <= 0) {
        ordDiscAmount = 0.0;
        ordDiscRate = 0.0;
      } else {
        ordDiscAmount = ordDiscAmount.clamp(0.0, itemsSub);
        ordDiscRate = itemsSub > 0 ? ((ordDiscAmount / itemsSub) * 100) : 0.0;
      }
    }

    final netSub = (itemsSub - ordDiscAmount).clamp(0.0, double.infinity);

    final taxState = _ref.read(taxNotifierProvider);
    final setting = taxState.taxSetting;

    double taxRate = 0.0;
    if (setting != null && setting.isEnabled) {
      taxRate = setting.percentage;
    }

    double serviceRate = 0.0;
    bool isAfterTax = false;
    if (setting != null && setting.isServiceChargeEnabled) {
      final orderState = _ref.read(orderNotifierProvider);
      final isTakeAwayOrOnline = orderState.isTakeAway || (orderState.activeOrder != null && orderState.activeOrder!.isTakeAway);
      if (isTakeAwayOrOnline && setting.isServiceChargeExcludeOnline) {
        serviceRate = 0.0;
      } else {
        serviceRate = setting.serviceChargePercentage;
      }
      isAfterTax = setting.isServiceChargeAfterTax;
    }

    double serviceAmount = 0.0;
    double taxAmount = 0.0;

    if (isAfterTax) {
      // Mode Setelah Pajak:
      // Pajak dihitung dari Net Subtotal
      taxAmount = (netSub * (taxRate / 100)).ceilToDouble();
      // Service Charge dihitung dari (Net Subtotal + Pajak)
      serviceAmount = ((netSub + taxAmount) * (serviceRate / 100)).ceilToDouble();
    } else {
      // Mode Sebelum Pajak:
      // Service Charge dihitung dari Net Subtotal
      serviceAmount = (netSub * (serviceRate / 100)).ceilToDouble();
      // Pajak dihitung dari (Net Subtotal + Service Charge)
      taxAmount = ((netSub + serviceAmount) * (taxRate / 100)).ceilToDouble();
    }

    double grand = netSub + serviceAmount + taxAmount;

    state = state.copyWith(
      items: activeItems,
      grossSubtotal: grossSub,
      itemDiscountTotal: itemDiscTotal,
      subtotal: itemsSub,
      orderDiscountRate: ordDiscRate,
      orderDiscountAmount: ordDiscAmount,
      orderDiscountType: ordDiscType,
      netSubtotal: netSub,
      taxRate: taxRate,
      taxAmount: taxAmount,
      serviceChargeRate: serviceRate,
      serviceChargeAmount: serviceAmount,
      serviceChargeAfterTax: isAfterTax,
      grandTotal: grand,
      errorMessage: null,
    );
  }

  void setItemDiscount(
    String productId, {
    required String discountType,
    required double discountValue,
    String? batchId,
  }) {
    final index = state.items.indexWhere(
      (item) => item.product.id == productId && item.batchId == batchId,
    );
    if (index == -1) return;

    final item = state.items[index];
    final gross = item.grossSubtotal;

    double discPercent = 0.0;
    double discAmount = 0.0;

    if (discountValue > 0) {
      if (discountType == 'percent') {
        discPercent = discountValue.clamp(0.0, 100.0);
        discAmount = (gross * (discPercent / 100)).clamp(0.0, gross);
      } else {
        discAmount = discountValue.clamp(0.0, gross);
        discPercent = gross > 0 ? ((discAmount / gross) * 100) : 0.0;
      }
    }

    final updatedItems = List<CartItem>.from(state.items);
    updatedItems[index] = item.copyWith(
      discountPercentage: discPercent,
      discountAmount: discAmount,
      discountType: discountType,
    );

    _recalculate(currentItems: updatedItems);
  }

  void clearItemDiscount(String productId, {String? batchId}) {
    setItemDiscount(productId, discountType: 'percent', discountValue: 0.0, batchId: batchId);
  }

  void setOrderDiscount({
    required String discountType,
    required double discountValue,
  }) {
    if (discountValue <= 0) {
      clearOrderDiscount();
      return;
    }

    _recalculate(
      orderDiscountType: discountType,
      orderDiscountRate: discountType == 'percent' ? discountValue : 0.0,
      orderDiscountAmount: discountType == 'nominal' ? discountValue : 0.0,
    );
  }

  void clearOrderDiscount() {
    _recalculate(
      orderDiscountType: 'percent',
      orderDiscountRate: 0.0,
      orderDiscountAmount: 0.0,
    );
  }

  String? _checkStockLimit(Product product, int targetQty, {String? targetBatchId, bool isBatchBaru = false}) {
    final productState = _ref.read(productNotifierProvider);
    final allProducts = productState.allProducts;
    final productMap = {for (var p in allProducts) p.id: p};

    final realProduct = productMap[product.id] ?? product;

    if (!realProduct.isPackage) {
      if (realProduct.stok == -1) return null; // Unlimited physical stock
      int totalNeeded = targetQty;

      // Add consumption by other cart items (both regular items in other batches and packages)
      for (var item in state.items) {
        if (isBatchBaru) {
          if (item.product.id == realProduct.id && item.batchId == null) continue;
        } else {
          if (item.product.id == realProduct.id && item.batchId == targetBatchId) continue;
        }

        if (!item.product.isPackage) {
          if (item.product.id == realProduct.id) {
            totalNeeded += item.qty;
          }
        } else {
          for (var comp in item.product.packageItems) {
            if (comp.productId == realProduct.id) {
              totalNeeded += comp.qty * item.qty;
            }
          }
        }
      }

      if (totalNeeded > realProduct.stok) {
        return 'Stok "${realProduct.nama}" tidak mencukupi (Sisa fisik: ${realProduct.stok})';
      }
      return null;
    }

    // It's a package
    if (realProduct.packageItems.isEmpty) {
      return 'Menu paket "${realProduct.nama}" belum memiliki item komponen!';
    }

    for (var comp in realProduct.packageItems) {
      final compProduct = productMap[comp.productId];
      final compPhysicalStock = compProduct?.stok ?? comp.productStok ?? -1;

      if (compPhysicalStock == -1) continue; // Non-stock component

      int totalCompNeeded = comp.qty * targetQty;

      // Add consumption by all other items in cart
      for (var item in state.items) {
        if (isBatchBaru) {
          if (item.product.id == realProduct.id && item.batchId == null) continue;
        } else {
          if (item.product.id == realProduct.id && item.batchId == targetBatchId) continue;
        }

        if (!item.product.isPackage) {
          if (item.product.id == comp.productId) {
            totalCompNeeded += item.qty;
          }
        } else {
          for (var innerComp in item.product.packageItems) {
            if (innerComp.productId == comp.productId) {
              totalCompNeeded += innerComp.qty * item.qty;
            }
          }
        }
      }

      if (totalCompNeeded > compPhysicalStock) {
        final compName = compProduct?.nama ?? comp.productNama ?? 'Komponen';
        return 'Stok "$compName" tidak mencukupi untuk paket "${realProduct.nama}" (Tersisa: $compPhysicalStock)';
      }
    }

    return null;
  }

  bool addItem(Product product) {
    final productState = _ref.read(productNotifierProvider);
    final freshProduct = productState.allProducts.firstWhere(
      (p) => p.id == product.id,
      orElse: () => product,
    );

    if (!freshProduct.isActive) {
      state = state.copyWith(errorMessage: 'Produk tidak aktif');
      return false;
    }

    // Always target uncommitted item (batchId == null) with no modifiers
    final existingIndex = state.items.indexWhere((item) => item.product.id == freshProduct.id && item.batchId == null && !item.hasModifiers);
    final targetQty = existingIndex != -1 ? state.items[existingIndex].qty + 1 : 1;

    final stockError = _checkStockLimit(freshProduct, targetQty, isBatchBaru: true);
    if (stockError != null) {
      state = state.copyWith(errorMessage: stockError);
      return false;
    }

    List<CartItem> updatedItems = List.from(state.items);

    if (existingIndex != -1) {
      final oldItem = state.items[existingIndex];
      // Recalculate discount if item had percentage discount
      double newDiscAmount = oldItem.discountAmount;
      if (oldItem.discountType == 'percent' && oldItem.discountPercentage > 0) {
        final newGross = oldItem.baseUnitPrice * targetQty;
        newDiscAmount = (newGross * (oldItem.discountPercentage / 100)).clamp(0.0, newGross);
      }
      updatedItems[existingIndex] = oldItem.copyWith(
        qty: targetQty,
        discountAmount: newDiscAmount,
      );
    } else {
      updatedItems.add(CartItem(product: freshProduct, qty: 1));
    }

    _recalculate(currentItems: updatedItems);
    return true;
  }

  bool addItemWithModifiers(
    Product product,
    List<SelectedModifier> modifiers, {
    int qty = 1,
    String catatan = '',
  }) {
    final productState = _ref.read(productNotifierProvider);
    final freshProduct = productState.allProducts.firstWhere(
      (p) => p.id == product.id,
      orElse: () => product,
    );

    if (!freshProduct.isActive) {
      state = state.copyWith(errorMessage: 'Produk tidak aktif');
      return false;
    }

    final modSig = (modifiers.map((m) => '${m.groupId}:${m.optionId}').toList()..sort()).join('|');
    final existingIndex = state.items.indexWhere(
      (item) => item.product.id == freshProduct.id && item.batchId == null && item.modifierSignature == modSig && item.catatan == catatan,
    );

    final targetQty = existingIndex != -1 ? state.items[existingIndex].qty + qty : qty;

    final stockError = _checkStockLimit(freshProduct, targetQty, isBatchBaru: true);
    if (stockError != null) {
      state = state.copyWith(errorMessage: stockError);
      return false;
    }

    List<CartItem> updatedItems = List.from(state.items);

    if (existingIndex != -1) {
      final oldItem = state.items[existingIndex];
      double newDiscAmount = oldItem.discountAmount;
      if (oldItem.discountType == 'percent' && oldItem.discountPercentage > 0) {
        final newGross = oldItem.baseUnitPrice * targetQty;
        newDiscAmount = (newGross * (oldItem.discountPercentage / 100)).clamp(0.0, newGross);
      }
      updatedItems[existingIndex] = oldItem.copyWith(
        qty: targetQty,
        discountAmount: newDiscAmount,
      );
    } else {
      updatedItems.add(CartItem(
        product: freshProduct,
        qty: qty,
        catatan: catatan,
        selectedModifiers: modifiers,
      ));
    }

    _recalculate(currentItems: updatedItems);
    return true;
  }

  bool addManualItem({
    required String nama,
    required double harga,
    required int qty,
    String catatan = '',
  }) {
    if (nama.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Nama item manual tidak boleh kosong');
      return false;
    }
    if (harga < 0) {
      state = state.copyWith(errorMessage: 'Harga tidak boleh negatif');
      return false;
    }
    if (qty <= 0) {
      state = state.copyWith(errorMessage: 'Jumlah item minimal 1');
      return false;
    }

    final manualId = 'manual_${DateTime.now().millisecondsSinceEpoch}_${state.items.length + 1}';
    final manualProduct = Product(
      id: manualId,
      kategoriId: 'manual',
      kategoriNama: 'Manual Order',
      nama: nama.trim(),
      harga: harga,
      stok: -1, // Non-stock item (unlimited & does not reduce physical inventory)
      isPackage: false,
      packageItems: const [],
      status: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final updatedItems = List<CartItem>.from(state.items);
    updatedItems.add(CartItem(
      product: manualProduct,
      qty: qty,
      catatan: catatan.trim(),
    ));

    _recalculate(currentItems: updatedItems);
    return true;
  }

  void removeItem(String productId, {String? batchId, String? modifierSignature}) {
    final updatedItems = state.items.where(
      (item) => !(item.product.id == productId && item.batchId == batchId && (modifierSignature == null || item.modifierSignature == modifierSignature)),
    ).toList();
    _recalculate(currentItems: updatedItems);
  }

  void removeItemByIndex(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updatedItems = List<CartItem>.from(state.items)..removeAt(index);
    _recalculate(currentItems: updatedItems);
  }

  bool updateQuantity(String productId, int newQty, {String? batchId, String? modifierSignature}) {
    final index = state.items.indexWhere(
      (item) => item.product.id == productId && item.batchId == batchId && (modifierSignature == null || item.modifierSignature == modifierSignature),
    );
    if (index == -1) return false;
    return updateQuantityByIndex(index, newQty);
  }

  bool updateQuantityByIndex(int index, int newQty) {
    if (index < 0 || index >= state.items.length) return false;

    final cartItem = state.items[index];

    // Prevent reducing quantity below previously saved/printed draft quantity
    if (newQty < cartItem.initialSavedQty) {
      state = state.copyWith(errorMessage: 'Pesanan yang sudah tersimpan / dikirim ke dapur tidak dapat dikurangi!');
      return false;
    }

    if (newQty <= 0) {
      removeItemByIndex(index);
      return true;
    }

    final stockError = _checkStockLimit(cartItem.product, newQty, targetBatchId: cartItem.batchId, isBatchBaru: cartItem.batchId == null);
    if (stockError != null) {
      state = state.copyWith(errorMessage: stockError);
      return false;
    }

    // Recalculate discount if percentage discount was active
    double newDiscAmount = cartItem.discountAmount;
    if (cartItem.discountType == 'percent' && cartItem.discountPercentage > 0) {
      final newGross = cartItem.baseUnitPrice * newQty;
      newDiscAmount = (newGross * (cartItem.discountPercentage / 100)).clamp(0.0, newGross);
    }

    List<CartItem> updatedItems = List.from(state.items);
    updatedItems[index] = cartItem.copyWith(
      qty: newQty,
      discountAmount: newDiscAmount,
    );

    _recalculate(currentItems: updatedItems);
    return true;
  }

  void updateCatatan(String productId, String catatan, {String? batchId, String? modifierSignature}) {
    final index = state.items.indexWhere(
      (item) => item.product.id == productId && item.batchId == batchId && (modifierSignature == null || item.modifierSignature == modifierSignature),
    );
    if (index == -1) return;
    updateCatatanByIndex(index, catatan);
  }

  void updateCatatanByIndex(int index, String catatan) {
    if (index < 0 || index >= state.items.length) return;

    List<CartItem> updatedItems = List.from(state.items);
    updatedItems[index] = state.items[index].copyWith(catatan: catatan);

    _recalculate(currentItems: updatedItems);
  }

  void loadDraftItems(
    List<OrderItemModel> draftItems,
    List<Product> allProducts,
    List<PrintBatchModel> batches, {
    double? orderDiscountPercentage,
    double? orderDiscountAmount,
    String? orderDiscountType,
  }) {
    final Map<String, CartItem> consolidatedMap = {};
    
    // Sort batches by createdAt to assign round numbers
    final sortedBatches = List<PrintBatchModel>.from(batches)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
    final batchIndices = {for (var i = 0; i < sortedBatches.length; i++) sortedBatches[i].id: i + 1};

    for (var draft in draftItems) {
      if (draft.isCancelled) continue;
      final productIndex = allProducts.indexWhere((p) => p.id == draft.produkId);
      final product = productIndex != -1
          ? allProducts[productIndex]
          : Product(
              id: draft.produkId,
              kategoriId: 'manual',
              nama: draft.produkNama,
              harga: draft.produkHarga,
              stok: -1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      final catatan = draft.catatan ?? '';
      final batchId = draft.printBatchId;
      final modSig = (draft.selectedModifiers.map((m) => '${m.groupId}:${m.optionId}').toList()..sort()).join('|');
      final key = '${product.id}_${catatan}_${batchId}_$modSig';

      bool isBilled = false;
      String? batchName;
      if (batchId != null) {
        final batch = batches.firstWhere((b) => b.id == batchId, orElse: () => PrintBatchModel(id: '', orderId: '', createdAt: DateTime.now()));
        if (batch.id.isNotEmpty) {
          isBilled = batch.paymentStatus == 'billed' || batch.paymentStatus == 'paid';
        }
        final roundNum = batchIndices[batchId] ?? 0;
        batchName = roundNum > 0 ? 'Round $roundNum' : null;
      }

      if (consolidatedMap.containsKey(key)) {
        final existing = consolidatedMap[key]!;
        final newQty = existing.qty + draft.qty;
        final newDiscAmount = existing.discountAmount + draft.discountAmount;
        consolidatedMap[key] = existing.copyWith(
          qty: newQty,
          initialSavedQty: newQty,
          discountAmount: newDiscAmount,
        );
      } else {
        consolidatedMap[key] = CartItem(
          product: product,
          qty: draft.qty,
          catatan: catatan,
          initialSavedQty: draft.qty,
          batchId: batchId,
          isBilled: isBilled,
          batchName: batchName,
          discountPercentage: draft.discountPercentage,
          discountAmount: draft.discountAmount,
          discountType: draft.discountPercentage > 0 ? 'percent' : 'nominal',
          selectedModifiers: draft.selectedModifiers,
        );
      }
    }
    
    // Sort items so earlier batches come first, and new items (null batchId) come last
    final sortedItems = consolidatedMap.values.toList()
      ..sort((a, b) {
        if (a.batchId == null && b.batchId == null) return 0;
        if (a.batchId == null) return 1;
        if (b.batchId == null) return -1;
        final indexA = batchIndices[a.batchId!] ?? 0;
        final indexB = batchIndices[b.batchId!] ?? 0;
        return indexA.compareTo(indexB);
      });

    final activeOrder = _ref.read(orderNotifierProvider).activeOrder;
    final effDiscountPct = orderDiscountPercentage ?? activeOrder?.discountPercentage;
    final effDiscountAmt = orderDiscountAmount ?? activeOrder?.discountAmount;
    final effDiscountType = orderDiscountType ??
        (effDiscountPct != null && effDiscountPct > 0
            ? 'percent'
            : (effDiscountAmt != null && effDiscountAmt > 0 ? 'nominal' : null));
      
    _recalculate(
      currentItems: sortedItems,
      orderDiscountRate: effDiscountPct,
      orderDiscountAmount: effDiscountAmt,
      orderDiscountType: effDiscountType,
    );
  }

  void clear() {
    state = CartState();
  }
}

final cartNotifierProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});
