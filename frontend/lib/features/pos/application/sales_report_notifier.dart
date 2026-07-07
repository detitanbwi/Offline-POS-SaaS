import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/di/providers.dart';
import '../domain/repositories/transaction_repository.dart';

class SalesReportState {
  final Map<String, dynamic>? reportData;
  final bool isLoading;
  final String? errorMessage;

  SalesReportState({
    this.reportData,
    this.isLoading = false,
    this.errorMessage,
  });

  SalesReportState copyWith({
    Map<String, dynamic>? reportData,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SalesReportState(
      reportData: reportData ?? this.reportData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SalesReportNotifier extends StateNotifier<SalesReportState> {
  final TransactionRepository _repository;

  SalesReportNotifier(this._repository) : super(SalesReportState());

  Future<void> loadDailyReport(DateTime date) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final data = await _repository.getDailySalesReport(dateStr);
      state = state.copyWith(reportData: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat laporan penjualan: $e',
      );
    }
  }
}

final salesReportNotifierProvider = StateNotifierProvider<SalesReportNotifier, SalesReportState>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return SalesReportNotifier(repo);
});
