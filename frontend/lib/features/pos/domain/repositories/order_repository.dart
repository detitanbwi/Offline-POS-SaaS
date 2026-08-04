import '../models/order.dart';
import '../models/order_item.dart';

abstract class OrderRepository {
  Future<OrderModel?> getActiveOrderForTable(String tableId);
  Future<List<OrderItemModel>> getOrderItems(String orderId);
  Future<void> saveOrder(OrderModel order, List<OrderItemModel> items, {bool markAsPrinted = false});
  Future<void> cancelOrder(String orderId, String tableId);
  Future<void> completeOrder(String orderId, {String? tableId});
  Future<void> transferOrderTable(
    String orderId,
    String oldTableId,
    String newTableId,
    String newTableName,
    String newTableNomor,
  );
  Future<String> generateNextOrderNumber();
  Future<Map<String, OrderModel>> getActiveOrdersMap();
  Future<List<OrderModel>> getAllDraftOrders();
  Future<int> getBatchCount(String orderId);
  Future<List<Map<String, dynamic>>> getPrintBatches(String orderId);
  Future<String> recordPrintBatch(String orderId);
  Future<void> markItemsAsPrinted(String orderId, String batchId);

  // New features
  Future<void> cancelOrderItem(String itemId, String reason);
  Future<void> cancelOrderBatch(String batchId, String reason);
  Future<void> clearTableOnly(String orderId, String tableId, String reason);
  Future<void> markTableBillPrinted(String tableId);
  Future<OrderModel?> getOrderById(String orderId);
}
