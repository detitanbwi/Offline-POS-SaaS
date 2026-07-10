import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/pos/application/order_notifier.dart';
import 'package:frontend/features/pos/domain/repositories/order_repository.dart';
import 'package:frontend/features/pos/domain/models/order.dart';
import 'package:frontend/features/pos/domain/models/order_item.dart';
import 'package:frontend/features/table/domain/models/table.dart';
import 'package:frontend/core/di/providers.dart';

class OrderRepositoryMock implements OrderRepository {
  OrderModel? mockActiveOrder;
  List<OrderItemModel> mockOrderItems = [];
  Map<String, OrderModel> mockActiveOrdersMap = {};
  bool saveOrderCalled = false;
  bool cancelOrderCalled = false;

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
  group('OrderNotifier and Draft Tests', () {
    late ProviderContainer container;
    late OrderRepositoryMock orderRepoMock;
    late TableModel sampleTable;

    setUp(() {
      orderRepoMock = OrderRepositoryMock();
      container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepoMock),
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
  });
}
