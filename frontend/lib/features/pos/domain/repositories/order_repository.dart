import '../models/order.dart';
import '../models/order_item.dart';

abstract class OrderRepository {
  Future<OrderModel?> getActiveOrderForTable(String tableId);
  Future<List<OrderItemModel>> getOrderItems(String orderId);
  Future<void> saveOrder(OrderModel order, List<OrderItemModel> items, {bool markAsPrinted = false});
  Future<void> cancelOrder(String orderId, String tableId);
  Future<void> completeOrder(String orderId);
  Future<void> transferOrderTable(
    String orderId,
    String oldTableId,
    String newTableId,
    String newTableName,
    String newTableNomor,
  );
  Future<String> generateNextOrderNumber();
  Future<Map<String, OrderModel>> getActiveOrdersMap();
  Future<int> getBatchCount(String orderId);
  Future<void> recordPrintBatch(String orderId);
}
