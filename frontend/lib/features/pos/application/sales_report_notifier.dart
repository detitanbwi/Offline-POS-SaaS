import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/di/providers.dart';
import '../../auth/domain/models/auth_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
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
  final AuthUser? _authUser;

  SalesReportNotifier(this._repository, this._authUser) : super(SalesReportState());

  Future<void> loadDailyReport(DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      String? cashierId;
      if (_authUser != null && _authUser!.isCashier) {
        cashierId = _authUser!.id;
      }

      final data = await _repository.getDailySalesReport(dateStr, cashierId: cashierId);
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
  final authUser = ref.watch(authSessionProvider);
  return SalesReportNotifier(repo, authUser);
});
