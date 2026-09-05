import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/di/providers.dart';
import '../../auth/domain/models/auth_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../pos/domain/models/transaction.dart';
import '../../pos/domain/repositories/transaction_repository.dart';

class TransactionHistoryState {
  final List<TransactionHeader> allTransactions;
  final List<TransactionHeader> filteredTransactions;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isLoading;
  final String? errorMessage;

  DateTime? get selectedDate => startDate;

  TransactionHistoryState({
    this.allTransactions = const [],
    this.filteredTransactions = const [],
    this.searchQuery = '',
    DateTime? startDate,
    DateTime? endDate,
    DateTime? selectedDate,
    this.isLoading = false,
    this.errorMessage,
  }) : startDate = startDate ?? selectedDate,
       endDate = endDate ?? selectedDate;

  TransactionHistoryState copyWith({
    List<TransactionHeader>? allTransactions,
    List<TransactionHeader>? filteredTransactions,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? selectedDate,
    bool clearDateRange = false,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TransactionHistoryState(
      allTransactions: allTransactions ?? this.allTransactions,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: clearDateRange ? null : (startDate ?? (selectedDate ?? this.startDate)),
      endDate: clearDateRange ? null : (endDate ?? (selectedDate ?? this.endDate)),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TransactionHistoryNotifier extends StateNotifier<TransactionHistoryState> {
  final TransactionRepository _repository;
  final AuthUser? _authUser;

  TransactionHistoryNotifier(this._repository, this._authUser) : super(TransactionHistoryState()) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      String? cashierId;
      if (_authUser != null && _authUser.isCashier) {
        cashierId = _authUser.id;
      }
      final list = await _repository.getAllTransactions(cashierId: cashierId);
      state = state.copyWith(
        allTransactions: list,
        isLoading: false,
      );
      _applyFilter();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat riwayat transaksi: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilter();
  }

  void setSelectedDate(DateTime? date) {
    if (date == null) {
      state = state.copyWith(clearDateRange: true);
    } else {
      state = state.copyWith(startDate: date, endDate: date);
    }
    _applyFilter();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      state = state.copyWith(clearDateRange: true);
    } else {
      state = state.copyWith(startDate: start, endDate: end ?? start);
    }
    _applyFilter();
  }

  void _applyFilter() {
    List<TransactionHeader> filtered = List.from(state.allTransactions);

    // Filter by date range
    if (state.startDate != null || state.endDate != null) {
      final start = state.startDate != null
          ? DateTime(state.startDate!.year, state.startDate!.month, state.startDate!.day, 0, 0, 0)
          : null;
      final end = state.endDate != null
          ? DateTime(state.endDate!.year, state.endDate!.month, state.endDate!.day, 23, 59, 59, 999)
          : null;

      filtered = filtered.where((t) {
        if (start != null && t.createdAt.isBefore(start)) {
          return false;
        }
        if (end != null && t.createdAt.isAfter(end)) {
          return false;
        }
        return true;
      }).toList();
    }

    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered
          .where((t) => t.nomorTransaksi.toLowerCase().contains(query) || t.paymentMethodNama.toLowerCase().contains(query))
          .toList();
    }
    state = state.copyWith(filteredTransactions: filtered);
  }

  Future<List<TransactionItem>> getItems(String id) async {
    return await _repository.getTransactionItems(id);
  }

  Future<bool> voidTransaction(String transactionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.voidTransaction(transactionId);
      await loadTransactions();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal membatalkan transaksi: $e');
      return false;
    }
  }
}

final transactionHistoryNotifierProvider =
    StateNotifierProvider<TransactionHistoryNotifier, TransactionHistoryState>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final authUser = ref.watch(authSessionProvider);
  return TransactionHistoryNotifier(repo, authUser);
});
