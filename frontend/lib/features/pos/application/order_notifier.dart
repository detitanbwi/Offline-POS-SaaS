import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
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
  final String orderType; // 'dine_in' or 'take_away'
  final String? customerName;
  final bool isLoading;
  final String? errorMessage;

  OrderState({
    this.selectedTable,
    this.activeOrder,
    this.activeOrderItems = const [],
    this.activeOrdersMap = const {},
    this.orderType = 'dine_in',
    this.customerName,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isTakeAway => orderType == 'take_away';

  OrderState copyWith({
    TableModel? selectedTable,
    OrderModel? activeOrder,
    List<OrderItemModel>? activeOrderItems,
    Map<String, OrderModel>? activeOrdersMap,
    String? orderType,
    String? customerName,
    bool? isLoading,
    String? errorMessage,
    bool clearActiveOrder = false,
    bool clearSelectedTable = false,
  }) {
    return OrderState(
      selectedTable: clearSelectedTable ? null : (selectedTable ?? this.selectedTable),
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      activeOrderItems: clearActiveOrder ? const [] : (activeOrderItems ?? this.activeOrderItems),
      activeOrdersMap: activeOrdersMap ?? this.activeOrdersMap,
      orderType: orderType ?? this.orderType,
      customerName: customerName ?? this.customerName,
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

  void setOrderType(String type) {
    if (type == 'take_away') {
      state = state.copyWith(orderType: 'take_away', clearSelectedTable: true);
    } else {
      state = state.copyWith(orderType: 'dine_in');
    }
  }

  void setCustomerName(String? name) {
    state = state.copyWith(customerName: name?.trim().isEmpty == true ? null : name?.trim());
  }

  Future<void> selectTable(TableModel? table) async {
    if (table != null) {
      state = OrderState(
        selectedTable: table,
        activeOrdersMap: state.activeOrdersMap,
        orderType: 'dine_in',
        customerName: state.customerName,
      );
      await loadActiveOrderForTable(table.id);
    } else {
      state = state.copyWith(clearSelectedTable: true);
    }
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
          customerName: activeOrder.customerName ?? state.customerName,
          orderType: activeOrder.orderType,
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

  Future<List<OrderItemModel>?> saveCurrentOrderDraft(
    List<CartItem> cartItems,
    double subtotal,
    double taxRate,
    double taxAmount,
    double grandTotal, {
    String? notes,
    String? customerName,
  }) async {
    final table = state.selectedTable;
    final isTakeAway = state.orderType == 'take_away';

    if (!isTakeAway && table == null) {
      state = state.copyWith(errorMessage: 'Meja belum dipilih untuk pesanan Dine-In.');
      return null;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final orderId = state.activeOrder?.id ?? _uuid.v4();
      final orderNo = state.activeOrder?.nomorOrder ?? await _repository.generateNextOrderNumber();
      final finalCustomerName = customerName ?? state.customerName;

      final orderHeader = OrderModel(
        id: orderId,
        nomorOrder: orderNo,
        tableId: isTakeAway ? null : table?.id,
        tableNama: isTakeAway ? 'Take Away' : table?.nama,
        tableNomor: isTakeAway ? '-' : table?.nomor,
        customerName: finalCustomerName,
        orderType: state.orderType,
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

      // 1. Save order to SQLite (upsert strategy — preserves existing item batch IDs)
      await _repository.saveOrder(orderHeader, allOrderItems);

      // 2. If there are items to print, record batch, mark items, generate receipt & send to kitchen
      if (itemsToPrint.isNotEmpty) {
        final batchCount = await _repository.getBatchCount(orderId);
        final currentBatchNo = batchCount + 1;
        final waveInfo = currentBatchNo == 1 ? '#1 (Baru)' : '#$currentBatchNo (Tambahan)';

        // Record the new batch and get its ID
        final batchId = await _repository.recordPrintBatch(orderId);
        // Mark all unprinted items (print_batch_id IS NULL) with this new batch
        await _repository.markItemsAsPrinted(orderId, batchId);

        try {
          final printerState = _ref.read(printerNotifierProvider);
          final kitchenPrinterList = printerState.configuredPrinters.where((p) => p.isKitchen).toList();
          final targetPrinter = kitchenPrinterList.isNotEmpty
              ? kitchenPrinterList.first
              : (printerState.configuredPrinters.isNotEmpty ? printerState.configuredPrinters.first : null);

          final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
            order: orderHeader,
            itemsToPrint: itemsToPrint,
            waveInfo: waveInfo,
            paperSize: targetPrinter?.escPosPaperSize ?? PaperSize.mm58,
            charsPerLine: targetPrinter?.effectiveCharsPerLine ?? 32,
            autoCut: targetPrinter?.autoCut ?? false,
          );

          if (targetPrinter != null) {
            await _ref.read(printerNotifierProvider.notifier).printBytes(targetPrinter, receiptBytes);
          } else {
            if (kDebugMode) {
              debugPrint('--- PRINT TO KITCHEN SIMULATOR ---');
              debugPrint(String.fromCharCodes(receiptBytes));
              debugPrint('----------------------------------');
            }
          }
        } catch (printErr) {
          debugPrint('Printer not available or unit test environment: $printErr');
        }
      }

      if (table != null) {
        _ref.read(tableNotifierProvider.notifier).loadTables();
        await loadActiveOrdersMap();
        await loadActiveOrderForTable(table.id);
      } else {
        state = state.copyWith(activeOrder: orderHeader, activeOrderItems: allOrderItems, isLoading: false);
      }
      return itemsToPrint;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan draft order: $e');
      return null;
    }
  }

  Future<bool> cancelCurrentOrder() async {
    final table = state.selectedTable;
    final order = state.activeOrder;
    if (order == null) {
      state = state.copyWith(errorMessage: 'Tidak ada order aktif untuk dibatalkan.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.cancelOrder(order.id, table?.id ?? '');
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
