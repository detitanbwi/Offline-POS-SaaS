import '../models/transaction.dart';

abstract class TransactionRepository {
  Future<List<TransactionHeader>> getAllTransactions();
  Future<List<TransactionItem>> getTransactionItems(String transactionId);
  Future<void> saveTransaction(TransactionHeader header, List<TransactionItem> items);
  Future<String> generateNextOrderNumber();
  Future<Map<String, dynamic>> getDailySalesReport(String dateStr);
}
