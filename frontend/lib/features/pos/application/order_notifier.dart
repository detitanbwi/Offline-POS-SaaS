import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../table/domain/models/table.dart';
import '../../table/application/table_notifier.dart';
import '../domain/models/order.dart';
import '../domain/models/order_item.dart';
import '../domain/models/cart_item.dart';
import '../domain/repositories/order_repository.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../printer/application/printer_notifier.dart';

class OrderState {
  final TableModel? selectedTable;
  final OrderModel? activeOrder;
  final List<OrderItemModel> activeOrderItems;
  final Map<String, OrderModel> activeOrdersMap;
  final bool isLoading;
  final String? errorMessage;

  OrderState({
    this.selectedTable,
    this.activeOrder,
    this.activeOrderItems = const [],
    this.activeOrdersMap = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  OrderState copyWith({
    TableModel? selectedTable,
    OrderModel? activeOrder,
    List<OrderItemModel>? activeOrderItems,
    Map<String, OrderModel>? activeOrdersMap,
    bool? isLoading,
    String? errorMessage,
    bool clearActiveOrder = false,
  }) {
    return OrderState(
      selectedTable: selectedTable ?? this.selectedTable,
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      activeOrderItems: clearActiveOrder ? const [] : (activeOrderItems ?? this.activeOrderItems),
      activeOrdersMap: activeOrdersMap ?? this.activeOrdersMap,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  final OrderRepository _repository;
  final Ref _ref;
  final _uuid = const Uuid();

  OrderNotifier(this._repository, this._ref) : super(OrderState());

  void selectTable(TableModel table) {
    state = OrderState(selectedTable: table);
  }

  Future<void> loadActiveOrdersMap() async {
    try {
      final map = await _repository.getActiveOrdersMap();
      state = state.copyWith(activeOrdersMap: map);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal memuat peta order aktif: $e');
    }
  }

  Future<void> loadActiveOrderForTable(String tableId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final activeOrder = await _repository.getActiveOrderForTable(tableId);
      if (activeOrder != null) {
        final items = await _repository.getOrderItems(activeOrder.id);
        state = state.copyWith(
          activeOrder: activeOrder,
          activeOrderItems: items,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          clearActiveOrder: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat draft order meja: $e',
      );
    }
  }

  Future<bool> saveCurrentOrderDraft(
    List<CartItem> cartItems,
    double subtotal,
    double taxRate,
    double taxAmount,
    double grandTotal, {
    String? notes,
  }) async {
    final table = state.selectedTable;
    if (table == null) {
      state = state.copyWith(errorMessage: 'Meja belum dipilih.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final orderId = state.activeOrder?.id ?? _uuid.v4();
      final orderNo = state.activeOrder?.nomorOrder ?? await _repository.generateNextOrderNumber();

      final orderHeader = OrderModel(
        id: orderId,
        nomorOrder: orderNo,
        tableId: table.id,
        tableNama: table.nama,
        tableNomor: table.nomor,
        subtotal: subtotal,
        taxPercentage: taxRate,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        status: 'draft',
        catatan: notes,
        createdAt: state.activeOrder?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Fetch existing items for this draft to calculate difference
      final dbItems = await _repository.getOrderItems(orderId);
      final Map<String, int> dbQtyMap = {for (var x in dbItems) x.produkId: x.qty};

      // Determine which items are new or have quantity increases
      final List<OrderItemModel> itemsToPrint = [];
      final List<OrderItemModel> allOrderItems = [];

      for (var cartItem in cartItems) {
        final prodId = cartItem.product.id;
        final currentQty = cartItem.qty;
        final dbQty = dbQtyMap[prodId] ?? 0;

        final orderItem = OrderItemModel(
          id: _uuid.v4(),
          orderId: orderId,
          produkId: prodId,
          produkNama: cartItem.product.nama,
          produkHarga: cartItem.product.harga,
          qty: currentQty,
          subtotal: cartItem.subtotal,
          catatan: cartItem.catatan,
          statusCetak: 0, 
        );
        allOrderItems.add(orderItem);

        if (currentQty > dbQty) {
          final printQty = currentQty - dbQty;
          itemsToPrint.add(orderItem.copyWith(qty: printQty, subtotal: cartItem.product.harga * printQty));
        }
      }

      // 1. If there are items to print, generate receipt & send to kitchen printer
      if (itemsToPrint.isNotEmpty) {
        final printerState = _ref.read(printerNotifierProvider);
        final hasKitchenPrinter = printerState.configuredPrinters.any((p) => p.isKitchen);

        final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
          order: orderHeader,
          itemsToPrint: itemsToPrint,
        );

        if (hasKitchenPrinter) {
          final kitchenPrinter = printerState.configuredPrinters.firstWhere((p) => p.isKitchen);
          await _ref.read(printerNotifierProvider.notifier).printBytes(kitchenPrinter, receiptBytes);
        } else {
          if (kDebugMode) {
            debugPrint('--- PRINT TO KITCHEN SIMULATOR ---');
            debugPrint(String.fromCharCodes(receiptBytes));
            debugPrint('----------------------------------');
          }
        }
      }

      // 2. Save order to SQLite and mark printed items as printed
      await _repository.saveOrder(orderHeader, allOrderItems, markAsPrinted: true);
      
      _ref.read(tableNotifierProvider.notifier).loadTables();
      await loadActiveOrdersMap();
      await loadActiveOrderForTable(table.id);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan draft order: $e');
      return false;
    }
  }

  Future<bool> cancelCurrentOrder() async {
    final table = state.selectedTable;
    final order = state.activeOrder;
    if (table == null || order == null) {
      state = state.copyWith(errorMessage: 'Tidak ada order aktif untuk dibatalkan.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.cancelOrder(order.id, table.id);
      _ref.read(tableNotifierProvider.notifier).loadTables();
      await loadActiveOrdersMap();
      state = OrderState(selectedTable: table, activeOrdersMap: state.activeOrdersMap);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal membatalkan order: $e');
      return false;
    }
  }

  void clearActiveOrder() {
    state = OrderState();
  }
}

final orderNotifierProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  final repo = ref.watch(orderRepositoryProvider);
  return OrderNotifier(repo, ref);
});
