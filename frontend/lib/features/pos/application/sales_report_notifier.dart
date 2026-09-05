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
  final DateTime selectedDate;
  final String? selectedCashierId; // null = Semua Kasir
  final String? selectedCashierName;

  SalesReportState({
    this.reportData,
    this.isLoading = false,
    this.errorMessage,
    DateTime? selectedDate,
    this.selectedCashierId,
    this.selectedCashierName,
  }) : selectedDate = selectedDate ?? DateTime.now();

  SalesReportState copyWith({
    Map<String, dynamic>? reportData,
    bool? isLoading,
    String? errorMessage,
    DateTime? selectedDate,
    String? selectedCashierId,
    bool clearCashier = false,
    String? selectedCashierName,
  }) {
    return SalesReportState(
      reportData: reportData ?? this.reportData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedCashierId: clearCashier ? null : (selectedCashierId ?? this.selectedCashierId),
      selectedCashierName: clearCashier ? null : (selectedCashierName ?? this.selectedCashierName),
    );
  }
}

class SalesReportNotifier extends StateNotifier<SalesReportState> {
  final TransactionRepository _repository;
  final AuthUser? _authUser;

  SalesReportNotifier(this._repository, this._authUser)
      : super(SalesReportState(
          selectedCashierId: _authUser != null && _authUser.isCashier ? _authUser.id : null,
          selectedCashierName: _authUser != null && _authUser.isCashier ? _authUser.nama : null,
        )) {
    loadDailyReport();
  }

  Future<void> loadDailyReport({DateTime? date, String? cashierId, String? cashierName, bool clearCashier = false}) async {
    final targetDate = date ?? state.selectedDate;
    final isCashierUser = _authUser != null && _authUser.isCashier;
    
    final targetCashierId = isCashierUser
        ? _authUser.id
        : (clearCashier ? null : (cashierId ?? state.selectedCashierId));
    final targetCashierName = isCashierUser
        ? _authUser.nama
        : (clearCashier ? null : (cashierName ?? state.selectedCashierName));

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      selectedDate: targetDate,
      selectedCashierId: targetCashierId,
      clearCashier: clearCashier && !isCashierUser,
      selectedCashierName: targetCashierName,
    );

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      
      String? effectiveCashierId;
      if (isCashierUser) {
        effectiveCashierId = _authUser.id;
      } else {
        effectiveCashierId = targetCashierId;
      }

      final data = await _repository.getDailySalesReport(dateStr, cashierId: effectiveCashierId);
      state = state.copyWith(reportData: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat laporan penjualan: $e',
      );
    }
  }

  void setDate(DateTime date) {
    loadDailyReport(date: date);
  }

  void setCashier(String? cashierId, String? cashierName) {
    if (_authUser != null && _authUser.isCashier) {
      return; // Kasir tidak boleh mengubah filter kasir
    }
    if (cashierId == null) {
      loadDailyReport(clearCashier: true);
    } else {
      loadDailyReport(cashierId: cashierId, cashierName: cashierName);
    }
  }
}

final salesReportNotifierProvider = StateNotifierProvider<SalesReportNotifier, SalesReportState>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final authUser = ref.watch(authSessionProvider);
  return SalesReportNotifier(repo, authUser);
});
