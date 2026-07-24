import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/pos/application/order_notifier.dart';
import 'package:frontend/features/pos/domain/repositories/order_repository.dart';
import 'package:frontend/features/pos/domain/models/order.dart';
import 'package:frontend/features/pos/domain/models/order_item.dart';
import 'package:frontend/features/pos/domain/models/cart_item.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/table/domain/models/table.dart';
import 'package:frontend/features/table/domain/repositories/table_repository.dart';
import 'package:frontend/features/printer/domain/repositories/printer_repository.dart';
import 'package:frontend/features/printer/domain/models/printer_config.dart';
import 'package:frontend/core/di/providers.dart';

class TableRepositoryMock implements TableRepository {
  final List<TableModel> tables = [];
  @override
  Future<List<TableModel>> getAllTables() async => tables;
  @override
  Future<TableModel?> getTableById(String id) async => null;
  @override
  Future<void> saveTable(TableModel table) async {}
  @override
  Future<void> deleteTable(String id) async {}
  @override
  Future<bool> isTableNameExists(String name, {String? excludeId}) async => false;
  @override
  Future<bool> isTableNumberExists(String number, {String? excludeId}) async => false;
  @override
  Future<void> updateTableStatus(String id, int status) async {}
}

class PrinterRepositoryMock implements PrinterRepository {
  @override
  Future<List<PrinterConfigModel>> getPrintersConfig() async => [];
  @override
  Future<PrinterConfigModel?> getPrinterConfigByType(String type) async => null;
  @override
  Future<void> savePrinterConfig(PrinterConfigModel config) async {}
  @override
  Future<void> deletePrinterConfig(String id) async {}
  @override
  Future<void> updatePrinterConnectionStatus(String id, bool isConnected) async {}
}

class OrderRepositoryMock implements OrderRepository {
  OrderModel? mockActiveOrder;
  List<OrderItemModel> mockOrderItems = [];
  Map<String, OrderModel> mockActiveOrdersMap = {};
  bool saveOrderCalled = false;
  bool cancelOrderCalled = false;
  int batchCounter = 0;
  bool markItemsAsPrintedCalled = false;

  @override
  Future<OrderModel?> getActiveOrderForTable(String tableId) async {
    return mockActiveOrder;
  }

  @override
  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    return mockOrderItems;
  }

  @override
  Future<void> saveOrder(OrderModel order, List<OrderItemModel> items, {bool markAsPrinted = false}) async {
    saveOrderCalled = true;
    mockActiveOrder = order;
    mockOrderItems = items;
  }

  @override
  Future<void> cancelOrder(String orderId, String tableId) async {
    cancelOrderCalled = true;
    mockActiveOrder = null;
    mockOrderItems = [];
  }

  @override
  Future<String> generateNextOrderNumber() async {
    return 'ORD-20260707-0001';
  }

  @override
  Future<Map<String, OrderModel>> getActiveOrdersMap() async {
    return mockActiveOrdersMap;
  }

  @override
  Future<int> getBatchCount(String orderId) async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getPrintBatches(String orderId) async {
    return [];
  }

  @override
  Future<String> recordPrintBatch(String orderId) async {
    batchCounter++;
    return 'batch-$batchCounter';
  }

  @override
  Future<void> markItemsAsPrinted(String orderId, String batchId) async {
    markItemsAsPrintedCalled = true;
  }

  @override
  Future<void> completeOrder(String orderId) async {
    mockActiveOrder = null;
    mockOrderItems = [];
  }

  @override
  Future<void> transferOrderTable(
    String orderId,
    String oldTableId,
    String newTableId,
    String newTableName,
    String newTableNomor,
  ) async {
    if (mockActiveOrder != null && mockActiveOrder!.id == orderId) {
      mockActiveOrder = mockActiveOrder!.copyWith(
        tableId: newTableId,
        tableNama: newTableName,
        tableNomor: newTableNomor,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderNotifier and Draft Tests', () {
    late ProviderContainer container;
    late OrderRepositoryMock orderRepoMock;
    late TableModel sampleTable;

    setUp(() {
      orderRepoMock = OrderRepositoryMock();
      container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepoMock),
          tableRepositoryProvider.overrideWithValue(TableRepositoryMock()),
          printerRepositoryProvider.overrideWithValue(PrinterRepositoryMock()),
        ],
      );

      sampleTable = TableModel(
        id: 'table-1',
        nomor: '01',
        nama: 'Meja 01',
        status: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    test('selectTable updates selected table state', () {
      final notifier = container.read(orderNotifierProvider.notifier);
      notifier.selectTable(sampleTable);

      final state = container.read(orderNotifierProvider);
      expect(state.selectedTable, sampleTable);
      expect(state.activeOrder, isNull);
    });

    test('loadActiveOrderForTable updates state when draft exists', () async {
      final now = DateTime.now();
      orderRepoMock.mockActiveOrder = OrderModel(
        id: 'order-123',
        nomorOrder: 'ORD-20260707-0001',
        tableId: 'table-1',
        tableNama: 'Meja 01',
        tableNomor: '01',
        subtotal: 15000.0,
        taxPercentage: 0.11,
        taxAmount: 1650.0,
        grandTotal: 16650.0,
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      );

      orderRepoMock.mockOrderItems = [
        OrderItemModel(
          id: 'item-1',
          orderId: 'order-123',
          produkId: 'prod-1',
          produkNama: 'Kopi Susu',
          produkHarga: 15000.0,
          qty: 1,
          subtotal: 15000.0,
          statusCetak: 1,
        )
      ];

      final notifier = container.read(orderNotifierProvider.notifier);
      notifier.selectTable(sampleTable);
      await notifier.loadActiveOrderForTable('table-1');

      final state = container.read(orderNotifierProvider);
      expect(state.activeOrder, isNotNull);
      expect(state.activeOrder!.id, 'order-123');
      expect(state.activeOrderItems.length, 1);
      expect(state.activeOrderItems.first.produkNama, 'Kopi Susu');
    });

    test('cancelCurrentOrder clears draft order and frees table', () async {
      final now = DateTime.now();
      orderRepoMock.mockActiveOrder = OrderModel(
        id: 'order-123',
        nomorOrder: 'ORD-20260707-0001',
        tableId: 'table-1',
        tableNama: 'Meja 01',
        tableNomor: '01',
        subtotal: 15000.0,
        taxPercentage: 0.11,
        taxAmount: 1650.0,
        grandTotal: 16650.0,
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      );

      final notifier = container.read(orderNotifierProvider.notifier);
      notifier.selectTable(sampleTable);
      await notifier.loadActiveOrderForTable('table-1');

      final success = await notifier.cancelCurrentOrder();
      expect(success, isTrue);
      expect(orderRepoMock.cancelOrderCalled, isTrue);

      final state = container.read(orderNotifierProvider);
      expect(state.activeOrder, isNull);
    });

    test('saveCurrentOrderDraft saves order and returns items to print', () async {
      final notifier = container.read(orderNotifierProvider.notifier);
      notifier.selectTable(sampleTable);

      final product = Product(
        id: 'prod-1',
        nama: 'Kopi Susu',
        harga: 15000.0,
        stok: 10,
        kategoriId: 'cat-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cartItems = [
        CartItem(product: product, qty: 2),
      ];

      final printedItems = await notifier.saveCurrentOrderDraft(
        cartItems,
        30000.0,
        0.11,
        3300.0,
        33300.0,
      );

      expect(printedItems, isNotNull);
      expect(printedItems!.length, 1);
      expect(printedItems.first.produkNama, 'Kopi Susu');
      expect(printedItems.first.qty, 2);
      expect(orderRepoMock.saveOrderCalled, isTrue);
    });

    test('saveCurrentOrderDraft supports Take Away without table', () async {
      final notifier = container.read(orderNotifierProvider.notifier);
      notifier.setOrderType('take_away');
      notifier.setCustomerName('Budi Test');

      final product = Product(
        id: 'prod-1',
        nama: 'Kopi Susu Take Away',
        harga: 18000.0,
        stok: 10,
        kategoriId: 'cat-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cartItems = [
        CartItem(product: product, qty: 1),
      ];

      final printedItems = await notifier.saveCurrentOrderDraft(
        cartItems,
        18000.0,
        0.0,
        0.0,
        18000.0,
      );

      expect(printedItems, isNotNull);
      expect(printedItems!.length, 1);
      expect(printedItems.first.produkNama, 'Kopi Susu Take Away');
      expect(orderRepoMock.mockActiveOrder?.isTakeAway, isTrue);
      expect(orderRepoMock.mockActiveOrder?.customerName, 'Budi Test');
      expect(orderRepoMock.mockActiveOrder?.tableId, isNull);
    });
  });
}
