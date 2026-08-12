import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
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
  final List<OrderModel> allDraftOrders;
  final String orderType; // 'dine_in' or 'take_away'
  final String? takeAwaySubType;
  final String? onlinePlatform;
  final String? customerName;
  final double? onlinePlatformTotal;
  final bool isLoading;
  final String? errorMessage;
  final int nextBatchNumber;

  OrderState({
    this.selectedTable,
    this.activeOrder,
    this.activeOrderItems = const [],
    this.activeOrdersMap = const {},
    this.allDraftOrders = const [],
    this.orderType = 'dine_in',
    this.takeAwaySubType,
    this.onlinePlatform,
    this.customerName,
    this.onlinePlatformTotal,
    this.isLoading = false,
    this.errorMessage,
    this.nextBatchNumber = 1,
  });

  bool get isTakeAway => orderType == 'take_away';
  bool get isOnlineFood => orderType == 'take_away' && takeAwaySubType == 'online_food';

  OrderState copyWith({
    TableModel? selectedTable,
    OrderModel? activeOrder,
    List<OrderItemModel>? activeOrderItems,
    Map<String, OrderModel>? activeOrdersMap,
    List<OrderModel>? allDraftOrders,
    String? orderType,
    String? takeAwaySubType,
    String? onlinePlatform,
    String? customerName,
    double? onlinePlatformTotal,
    bool? isLoading,
    String? errorMessage,
    int? nextBatchNumber,
    bool clearActiveOrder = false,
    bool clearSelectedTable = false,
    bool clearOnlinePlatformTotal = false,
  }) {
    return OrderState(
      selectedTable: clearSelectedTable ? null : (selectedTable ?? this.selectedTable),
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      activeOrderItems: clearActiveOrder ? const [] : (activeOrderItems ?? this.activeOrderItems),
      activeOrdersMap: activeOrdersMap ?? this.activeOrdersMap,
      allDraftOrders: allDraftOrders ?? this.allDraftOrders,
      orderType: orderType ?? this.orderType,
      takeAwaySubType: takeAwaySubType ?? this.takeAwaySubType,
      onlinePlatform: onlinePlatform ?? this.onlinePlatform,
      customerName: customerName ?? this.customerName,
      onlinePlatformTotal: clearOnlinePlatformTotal ? null : (onlinePlatformTotal ?? this.onlinePlatformTotal),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      nextBatchNumber: clearActiveOrder ? 1 : (nextBatchNumber ?? this.nextBatchNumber),
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  final OrderRepository _repository;
  final Ref _ref;
  final _uuid = const Uuid();

  OrderNotifier(this._repository, this._ref) : super(OrderState());

  void resetOrder() {
    state = OrderState(
      activeOrdersMap: state.activeOrdersMap,
      allDraftOrders: state.allDraftOrders,
    );
  }

  void setOrderType(String type, {String? subType, String? platform, bool clearActiveOrder = true}) {
    if (type == 'take_away') {
      state = state.copyWith(
        orderType: 'take_away',
        takeAwaySubType: subType,
        onlinePlatform: platform,
        clearSelectedTable: true,
        clearActiveOrder: clearActiveOrder,
      );
    } else {
      state = state.copyWith(
        orderType: 'dine_in',
        takeAwaySubType: null,
        onlinePlatform: null,
        clearOnlinePlatformTotal: true,
        clearActiveOrder: clearActiveOrder,
      );
    }
  }

  void setCustomerName(String? name) {
    state = state.copyWith(customerName: name?.trim().isEmpty == true ? null : name?.trim());
  }

  void setOnlinePlatformTotal(double? total) {
    state = state.copyWith(onlinePlatformTotal: total);
  }

  Future<void> selectTable(TableModel? table) async {
    if (table != null) {
      state = OrderState(
        selectedTable: table,
        activeOrdersMap: state.activeOrdersMap,
        allDraftOrders: state.allDraftOrders,
        orderType: 'dine_in',
        customerName: state.customerName,
      );
      await loadActiveOrderForTable(table.id);
    } else {
      state = state.copyWith(clearSelectedTable: true);
    }
  }

  void setSelectedTableWithoutReset(TableModel? table) {
    state = state.copyWith(selectedTable: table);
  }

  Future<void> loadActiveOrdersMap() async {
    try {
      final map = await _repository.getActiveOrdersMap();
      final drafts = await _repository.getAllDraftOrders();
      state = state.copyWith(activeOrdersMap: map, allDraftOrders: drafts);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal memuat peta order aktif: $e');
    }
  }

  /// Load an existing draft order by ID into active state (used when resuming Take Away / Open Bill).
  Future<void> loadOrderById(String orderId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final order = await _repository.getOrderById(orderId);
      if (order == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Order tidak ditemukan.');
        return;
      }
      final items = await _repository.getOrderItems(orderId);
      final batchCount = await _repository.getBatchCount(orderId);
      state = state.copyWith(
        activeOrder: order,
        activeOrderItems: items,
        orderType: order.orderType,
        takeAwaySubType: order.takeAwaySubType,
        onlinePlatform: order.onlinePlatform,
        onlinePlatformTotal: order.onlinePlatformTotal,
        customerName: order.customerName ?? state.customerName,
        isLoading: false,
        nextBatchNumber: batchCount + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat order: $e');
    }
  }

  Future<void> loadActiveOrderForTable(String tableId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final activeOrder = await _repository.getActiveOrderForTable(tableId);
      if (activeOrder != null) {
        final items = await _repository.getOrderItems(activeOrder.id);
        final batchCount = await _repository.getBatchCount(activeOrder.id);
        state = state.copyWith(
          activeOrder: activeOrder,
          activeOrderItems: items,
          customerName: activeOrder.customerName ?? state.customerName,
          orderType: activeOrder.orderType,
          takeAwaySubType: activeOrder.takeAwaySubType,
          onlinePlatform: activeOrder.onlinePlatform,
          onlinePlatformTotal: activeOrder.onlinePlatformTotal,
          isLoading: false,
          nextBatchNumber: batchCount + 1,
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
    String? cashierId,
    String? cashierNama,
    bool printToKitchen = true,
  }) async {
    final table = state.selectedTable;
    final activeTableId = table?.id ?? state.activeOrder?.tableId;
    final activeTableNama = table?.nama ?? state.activeOrder?.tableNama;
    final activeTableNomor = table?.nomor ?? state.activeOrder?.tableNomor;

    final isTakeAway = state.orderType == 'take_away' || (state.activeOrder != null && state.activeOrder!.orderType == 'take_away');

    if (!isTakeAway && activeTableId == null) {
      state = state.copyWith(errorMessage: 'Meja belum dipilih untuk pesanan Dine-In.');
      return null;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final orderId = state.activeOrder?.id ?? _uuid.v4();
      final orderNo = state.activeOrder?.nomorOrder ?? await _repository.generateNextOrderNumber();
      final finalCustomerName = customerName ?? state.customerName;

      final authUser = _ref.read(authSessionProvider);
      final effectiveCashierId = cashierId ?? state.activeOrder?.cashierId ?? authUser?.id;
      final effectiveCashierNama = cashierNama ?? state.activeOrder?.cashierNama ?? authUser?.nama;

      final orderHeader = OrderModel(
        id: orderId,
        nomorOrder: orderNo,
        tableId: isTakeAway ? null : activeTableId,
        tableNama: isTakeAway ? 'Take Away' : (activeTableNama ?? 'Meja'),
        tableNomor: isTakeAway ? '-' : (activeTableNomor ?? '-'),
        customerName: finalCustomerName,
        orderType: state.orderType,
        takeAwaySubType: state.takeAwaySubType,
        onlinePlatform: state.onlinePlatform,
        subtotal: subtotal,
        taxPercentage: taxRate,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        onlinePlatformTotal: state.onlinePlatformTotal ?? state.activeOrder?.onlinePlatformTotal,
        platformDifference: (state.onlinePlatformTotal ?? state.activeOrder?.onlinePlatformTotal) != null
            ? ((state.onlinePlatformTotal ?? state.activeOrder!.onlinePlatformTotal!) - (subtotal + taxAmount))
            : (state.activeOrder?.platformDifference),
        status: 'draft',
        catatan: notes,
        cashierId: effectiveCashierId,
        cashierNama: effectiveCashierNama,
        createdAt: state.activeOrder?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Fetch existing items for this draft to calculate difference
      final dbItems = await _repository.getOrderItems(orderId);
      
      final List<OrderItemModel> allOrderItems = [];
      final Map<String, int> printedQtyMap = {};

      for (var item in dbItems) {
        if (item.printBatchId != null || item.statusCetak == 1) {
          allOrderItems.add(item);
          if (!item.isCancelled) {
            printedQtyMap[item.produkId] = (printedQtyMap[item.produkId] ?? 0) + item.qty;
          }
        }
      }

      final List<OrderItemModel> itemsToPrint = [];

      final Map<String, CartItem> cartItemMap = {};
      final Map<String, int> cartQtyMap = {};
      for (var cartItem in cartItems) {
        final prodId = cartItem.product.id;
        cartQtyMap[prodId] = (cartQtyMap[prodId] ?? 0) + cartItem.qty;
        cartItemMap[prodId] = cartItem;
      }

      for (var prodId in cartQtyMap.keys) {
        final cartItem = cartItemMap[prodId]!;
        final currentQty = cartQtyMap[prodId]!;
        final printedQty = printedQtyMap[prodId] ?? 0;

        if (currentQty > printedQty) {
          final unprintedQty = currentQty - printedQty;
          
          final orderItem = OrderItemModel(
            id: _uuid.v4(),
            orderId: orderId,
            produkId: prodId,
            produkNama: cartItem.product.nama,
            produkHarga: cartItem.product.harga,
            qty: unprintedQty,
            subtotal: cartItem.product.harga * unprintedQty,
            catatan: cartItem.catatan,
            statusCetak: 0,
            printBatchId: null,
          );
          allOrderItems.add(orderItem);
          itemsToPrint.add(orderItem);
        }
      }

      // 1. Save order to SQLite (upsert strategy — preserves existing item batch IDs)
      await _repository.saveOrder(orderHeader, allOrderItems);

      // 2. Record print batch and optionally print to kitchen
      if (itemsToPrint.isNotEmpty) {
        final batchCount = await _repository.getBatchCount(orderId);
        final currentBatchNo = batchCount + 1;
        final waveInfo = currentBatchNo == 1 ? '#1 (Baru)' : '#$currentBatchNo (Tambahan)';

        // Record the new batch and get its ID
        final batchId = await _repository.recordPrintBatch(orderId);
        // Mark all unprinted items (print_batch_id IS NULL) with this new batch
        await _repository.markItemsAsPrinted(orderId, batchId);

        if (printToKitchen) {
          try {
            await _ref.read(printerNotifierProvider.notifier).loadPrinters();
            final printerState = _ref.read(printerNotifierProvider);
            final kitchenPrinterList = printerState.configuredPrinters.where((p) => p.isKitchen).toList();
            final targetPrinter = kitchenPrinterList.isNotEmpty
                ? kitchenPrinterList.first
                : (printerState.configuredPrinters.isNotEmpty ? printerState.configuredPrinters.first : null);

            final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
              order: orderHeader,
              itemsToPrint: itemsToPrint,
              waveInfo: waveInfo,
              cashierNama: effectiveCashierNama,
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
      }

      await loadActiveOrdersMap();
      if (table != null) {
        _ref.read(tableNotifierProvider.notifier).loadTables();
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

  void resetForNewTransaction() {
    state = OrderState(
      activeOrdersMap: state.activeOrdersMap,
      allDraftOrders: state.allDraftOrders, // Pertahankan list Open Bill
      orderType: 'dine_in',
      selectedTable: null,
      activeOrder: null,
      activeOrderItems: const [],
      customerName: null,
      takeAwaySubType: null,
      onlinePlatform: null,
      nextBatchNumber: 1,
      isLoading: false,
      errorMessage: null,
    );
    // Refresh list Open Bill dari database setelah reset
    loadActiveOrdersMap();
  }

  Future<bool> cancelOrderItem(String itemId, String reason) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.cancelOrderItem(itemId, reason);
      if (state.selectedTable != null) {
        await loadActiveOrderForTable(state.selectedTable!.id);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal membatalkan item: $e');
      return false;
    }
  }

  Future<bool> cancelOrderBatch(String batchId, String reason) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.cancelOrderBatch(batchId, reason);
      if (state.selectedTable != null) {
        await loadActiveOrderForTable(state.selectedTable!.id);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal membatalkan batch: $e');
      return false;
    }
  }

  Future<bool> clearTableOnly(String reason) async {
    final table = state.selectedTable;
    final order = state.activeOrder;
    if (order == null || table == null) {
      state = state.copyWith(errorMessage: 'Tidak ada order atau meja aktif.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.clearTableOnly(order.id, table.id, reason);
      _ref.read(tableNotifierProvider.notifier).loadTables();
      await loadActiveOrdersMap();
      state = OrderState(selectedTable: table, activeOrdersMap: state.activeOrdersMap);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal mengosongkan meja: $e');
      return false;
    }
  }

  Future<bool> reprintKitchenTicket(String orderId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final order = await _repository.getOrderById(orderId);
      final items = await _repository.getOrderItems(orderId);
      if (order == null || items.isEmpty) {
        state = state.copyWith(isLoading: false, errorMessage: 'Order tidak ditemukan.');
        return false;
      }

      final printerState = _ref.read(printerNotifierProvider);
      final kitchenPrinterList = printerState.configuredPrinters.where((p) => p.isKitchen).toList();
      final targetPrinter = kitchenPrinterList.isNotEmpty
          ? kitchenPrinterList.first
          : (printerState.configuredPrinters.isNotEmpty ? printerState.configuredPrinters.first : null);

      final receiptBytes = await ReceiptGenerator.generateKitchenTicket(
        order: order,
        itemsToPrint: items,
        waveInfo: '(REPRINT - JANGAN DIMASAK ULANG)',
        paperSize: targetPrinter?.escPosPaperSize ?? PaperSize.mm58,
        charsPerLine: targetPrinter?.effectiveCharsPerLine ?? 32,
        autoCut: targetPrinter?.autoCut ?? false,
      );

      if (targetPrinter != null) {
        await _ref.read(printerNotifierProvider.notifier).printBytes(targetPrinter, receiptBytes);
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal reprint kitchen ticket: $e');
      return false;
    }
  }

  Future<bool> clearOccupiedTable(TableModel table, [String reason = 'Dikosongkan manual']) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final order = state.activeOrder ?? state.activeOrdersMap[table.id];
      debugPrint('[CLEAR_TABLE_DEBUG] Clearing table ID: ${table.id}, Name: ${table.nama}, Order ID: ${order?.id}');
      await _repository.clearTableOnly(order?.id ?? '', table.id, reason);
      
      await _ref.read(tableNotifierProvider.notifier).loadTables();
      await loadActiveOrdersMap();
      state = OrderState(selectedTable: null, activeOrdersMap: state.activeOrdersMap);
      debugPrint('[CLEAR_TABLE_DEBUG] Table successfully cleared and state refreshed.');
      return true;
    } catch (e) {
      debugPrint('[CLEAR_TABLE_DEBUG] Error clearing table: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal mengosongkan meja: $e');
      return false;
    }
  }
}

final orderNotifierProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  final repo = ref.watch(orderRepositoryProvider);
  return OrderNotifier(repo, ref);
});
