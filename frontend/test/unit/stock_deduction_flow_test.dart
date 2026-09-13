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
  @override
  Future<List<TableModel>> getDeletedTables() async => [];
  @override
  Future<void> restoreTable(String id) async {}
  @override
  Future<void> permanentDeleteTable(String id) async {}
}

class PrinterRepositoryMock implements PrinterRepository {
  @override
  Future<List<PrinterConfigModel>> getPrintersConfig() async => [];
  @override
  Future<PrinterConfigModel?> getPrinterConfigByType(String type) async => null;
  @override
  Future<PrinterConfigModel?> getPrinterConfigById(String id) async => null;
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
  bool markItemsAsPrintedCalled = false;
  bool lastDeductStock = true;

  @override
  Future<List<OrderModel>> getAllDraftOrders() async => mockActiveOrdersMap.values.toList();

  @override
  Future<OrderModel?> getActiveOrderForTable(String tableId) async => mockActiveOrder;

  @override
  Future<List<OrderItemModel>> getOrderItems(String orderId) async => mockOrderItems;

  @override
  Future<void> saveOrder(OrderModel order, List<OrderItemModel> items, {bool markAsPrinted = false}) async {
    saveOrderCalled = true;
    mockActiveOrder = order;
    mockOrderItems = items;
  }

  @override
  Future<void> cancelOrder(String orderId, String tableId) async {}

  @override
  Future<String> generateNextOrderNumber() async => 'ORD-20260913-0001';

  @override
  Future<Map<String, OrderModel>> getActiveOrdersMap() async => mockActiveOrdersMap;

  @override
  Future<int> getBatchCount(String orderId) async => 0;

  @override
  Future<List<Map<String, dynamic>>> getPrintBatches(String orderId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getPrintBatchesWithItems(String orderId) async => [];

  @override
  Future<void> updatePaymentStatus(String orderId, String status) async {}

  @override
  Future<void> updatePrintBatchPaymentStatus(String batchId, String status) async {}

  @override
  Future<String> recordPrintBatch(String orderId) async => 'batch-1';

  @override
  Future<void> markItemsAsPrinted(String orderId, String batchId, {bool deductStock = true}) async {
    markItemsAsPrintedCalled = true;
    lastDeductStock = deductStock;
  }

  @override
  Future<void> completeOrder(String orderId, {String? tableId}) async {}

  @override
  Future<void> transferOrderTable(
    String orderId,
    String oldTableId,
    String newTableId,
    String newTableName,
    String newTableNomor,
  ) async {}

  @override
  Future<void> cancelOrderItem(String itemId, String reason) async {}

  @override
  Future<void> cancelOrderBatch(String batchId, String reason) async {}

  @override
  Future<void> clearTableOnly(String orderId, String tableId, String reason) async {}

  @override
  Future<void> markTableBillPrinted(String tableId) async {}

  @override
  Future<void> markOrderBillPrinted(String orderId) async {}

  @override
  Future<OrderModel?> getOrderById(String orderId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stock Deduction Flow Tests', () {
    late ProviderContainer container;
    late OrderRepositoryMock orderRepoMock;

    final dummyProduct = Product(
      id: 'prod-1',
      kategoriId: 'cat-1',
      nama: 'Nasi Campur',
      harga: 25000,
      stok: 10,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      orderRepoMock = OrderRepositoryMock();
      container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepoMock),
          tableRepositoryProvider.overrideWithValue(TableRepositoryMock()),
          printerRepositoryProvider.overrideWithValue(PrinterRepositoryMock()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('OrderItemModel serializes and deserializes isStockDeducted properly', () {
      final item = OrderItemModel(
        id: 'item-1',
        orderId: 'ord-1',
        produkId: 'prod-1',
        produkNama: 'Nasi Campur',
        produkHarga: 25000,
        qty: 2,
        subtotal: 50000,
        isStockDeducted: 1,
      );

      final map = item.toMap();
      expect(map['is_stock_deducted'], 1);

      final fromMap = OrderItemModel.fromMap(map);
      expect(fromMap.isStockDeducted, 1);
    });

    test('Dine In kitchen dispatch sets deductStock = true', () async {
      final notifier = container.read(orderNotifierProvider.notifier);
      final dummyTable = TableModel(
        id: 't-1',
        nomor: '01',
        nama: 'Meja 01',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      notifier.selectTable(dummyTable);

      final cartItems = [
        CartItem(product: dummyProduct, qty: 1),
      ];

      await notifier.saveCurrentOrderDraft(
        cartItems,
        25000,
        0,
        0,
        25000,
        deductStock: true,
      );

      expect(orderRepoMock.markItemsAsPrintedCalled, isTrue);
      expect(orderRepoMock.lastDeductStock, isTrue);
    });

    test('Direct Payment flow passes deductStock = false so kitchen dispatch does not duplicate deduction', () async {
      final notifier = container.read(orderNotifierProvider.notifier);
      notifier.setOrderType('take_away');

      final cartItems = [
        CartItem(product: dummyProduct, qty: 1),
      ];

      await notifier.saveCurrentOrderDraft(
        cartItems,
        25000,
        0,
        0,
        25000,
        deductStock: false,
      );

      expect(orderRepoMock.markItemsAsPrintedCalled, isTrue);
      expect(orderRepoMock.lastDeductStock, isFalse);
    });
  });
}
