import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/domain/models/auth_user.dart';
import 'package:frontend/features/pos/domain/models/transaction.dart';
import 'package:frontend/features/pos/domain/repositories/transaction_repository.dart';
import 'package:frontend/features/transaction_history/application/transaction_history_notifier.dart';
import 'package:frontend/features/pos/application/sales_report_notifier.dart';

class MockTransactionRepository implements TransactionRepository {
  final List<TransactionHeader> transactions = [];

  @override
  Future<List<TransactionHeader>> getAllTransactions({String? cashierId}) async {
    if (cashierId != null) {
      return transactions.where((t) => t.cashierId == cashierId).toList();
    }
    return transactions;
  }

  @override
  Future<List<TransactionItem>> getTransactionItems(String transactionId) async {
    return [];
  }

  @override
  Future<void> voidTransaction(String transactionId) async {
    transactions.removeWhere((t) => t.id == transactionId);
  }

  @override
  Future<Map<String, dynamic>> getDailySalesReport(String date, {String? endDateStr, String? cashierId}) async {
    return {
      'date': date,
      'cashier_id': cashierId,
      'total_sales': 100000.0,
      'total_transactions': 1,
      'total_tax': 0.0,
      'payment_breakdown': {'Tunai': 100000.0},
      'top_products': <Map<String, dynamic>>[],
      'top_modifiers': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> saveTransaction(TransactionHeader header, List<TransactionItem> items) async {
    transactions.add(header);
  }

  @override
  Future<String> generateNextOrderNumber() async {
    return 'ORD-001';
  }
}

void main() {
  group('TransactionHistoryNotifier Date Range Tests', () {
    late MockTransactionRepository mockRepo;
    const ownerUser = AuthUser(
      id: 'owner-1',
      nama: 'Owner Test',
      role: 'pemilik',
    );

    setUp(() {
      mockRepo = MockTransactionRepository();
      mockRepo.transactions.addAll([
        TransactionHeader(
          id: 'tx-1',
          nomorTransaksi: 'TRX-001',
          cashierId: 'kasir-1',
          cashierNama: 'Kasir Satu',
          subtotal: 10000,
          taxPercentage: 0,
          taxAmount: 0,
          grandTotal: 10000,
          paymentMethodId: 'cash',
          paymentMethodNama: 'Tunai',
          nominalBayar: 10000,
          kembalian: 0,
          createdAt: DateTime(2026, 9, 1, 10, 0),
        ),
        TransactionHeader(
          id: 'tx-2',
          nomorTransaksi: 'TRX-002',
          cashierId: 'kasir-2',
          cashierNama: 'Kasir Dua',
          subtotal: 20000,
          taxPercentage: 0,
          taxAmount: 0,
          grandTotal: 20000,
          paymentMethodId: 'qris',
          paymentMethodNama: 'QRIS',
          nominalBayar: 20000,
          kembalian: 0,
          createdAt: DateTime(2026, 9, 3, 14, 0),
        ),
        TransactionHeader(
          id: 'tx-3',
          nomorTransaksi: 'TRX-003',
          cashierId: 'kasir-1',
          cashierNama: 'Kasir Satu',
          subtotal: 30000,
          taxPercentage: 0,
          taxAmount: 0,
          grandTotal: 30000,
          paymentMethodId: 'cash',
          paymentMethodNama: 'Tunai',
          nominalBayar: 30000,
          kembalian: 0,
          createdAt: DateTime(2026, 9, 5, 8, 30),
        ),
      ]);
    });

    test('Filters by single date and date range correctly', () async {
      final notifier = TransactionHistoryNotifier(mockRepo, ownerUser);
      await notifier.loadTransactions();

      expect(notifier.state.filteredTransactions.length, 3);

      // Filter single day (01 Sep 2026)
      notifier.setSelectedDate(DateTime(2026, 9, 1));
      expect(notifier.state.filteredTransactions.length, 1);
      expect(notifier.state.filteredTransactions.first.nomorTransaksi, 'TRX-001');

      // Filter date range (02 Sep 2026 to 05 Sep 2026)
      notifier.setDateRange(DateTime(2026, 9, 2), DateTime(2026, 9, 5));
      expect(notifier.state.filteredTransactions.length, 2);
      expect(notifier.state.filteredTransactions.map((t) => t.nomorTransaksi).toSet(), {'TRX-002', 'TRX-003'});

      // Clear filter
      notifier.setDateRange(null, null);
      expect(notifier.state.filteredTransactions.length, 3);
    });
  });

  group('SalesReportNotifier Cashier Access Control Tests', () {
    late MockTransactionRepository mockRepo;
    const cashierUser = AuthUser(
      id: 'kasir-1',
      nama: 'Budi Kasir',
      role: 'kasir',
    );

    const ownerUser = AuthUser(
      id: 'owner-1',
      nama: 'Owner Dedi',
      role: 'pemilik',
    );

    setUp(() {
      mockRepo = MockTransactionRepository();
    });

    test('Cashier role cannot change cashier filter', () async {
      final notifier = SalesReportNotifier(mockRepo, cashierUser);
      await notifier.loadDailyReport();

      expect(notifier.state.selectedCashierId, 'kasir-1');
      expect(notifier.state.selectedCashierName, 'Budi Kasir');

      // Attempt to change cashier as cashier
      notifier.setCashier('other-kasir', 'Other Kasir');
      expect(notifier.state.selectedCashierId, 'kasir-1');
      expect(notifier.state.selectedCashierName, 'Budi Kasir');
    });

    test('Owner role can change cashier filter', () async {
      final notifier = SalesReportNotifier(mockRepo, ownerUser);
      await notifier.loadDailyReport();

      expect(notifier.state.selectedCashierId, null);

      // Owner selects specific cashier
      notifier.setCashier('kasir-2', 'Siti Kasir');
      expect(notifier.state.selectedCashierId, 'kasir-2');
      expect(notifier.state.selectedCashierName, 'Siti Kasir');

      // Owner resets to all cashiers
      notifier.setCashier(null, null);
      expect(notifier.state.selectedCashierId, null);
    });
  });
}
