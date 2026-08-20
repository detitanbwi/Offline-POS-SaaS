import '../models/transaction.dart';

abstract class TransactionRepository {
  Future<List<TransactionHeader>> getAllTransactions({String? cashierId});
  Future<List<TransactionItem>> getTransactionItems(String transactionId);
  Future<void> saveTransaction(TransactionHeader header, List<TransactionItem> items);
  Future<void> voidTransaction(String transactionId);
  Future<String> generateNextOrderNumber();
  Future<Map<String, dynamic>> getDailySalesReport(String dateStr, {String? cashierId});
}
