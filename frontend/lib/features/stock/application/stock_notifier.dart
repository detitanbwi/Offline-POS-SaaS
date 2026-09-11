import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../product/application/product_notifier.dart';
import '../domain/models/stock_in.dart';
import '../domain/repositories/stock_repository.dart';

class StockState {
  final List<StockIn> allStockIn;
  final List<StockIn> filteredStockIn;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isLoading;
  final String? errorMessage;

  StockState({
    this.allStockIn = const [],
    this.filteredStockIn = const [],
    this.startDate,
    this.endDate,
    this.isLoading = false,
    this.errorMessage,
  });

  StockState copyWith({
    List<StockIn>? allStockIn,
    List<StockIn>? filteredStockIn,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    bool? isLoading,
    String? errorMessage,
  }) {
    return StockState(
      allStockIn: allStockIn ?? this.allStockIn,
      filteredStockIn: filteredStockIn ?? this.filteredStockIn,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class StockNotifier extends StateNotifier<StockState> {
  final StockRepository _repository;
  final Ref _ref;
  final _uuid = const Uuid();

  StockNotifier(this._repository, this._ref) : super(StockState()) {
    loadStockIn();
  }

  Future<void> loadStockIn() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final logs = await _repository.getAllStockIn();
      if (!mounted) return;
      state = state.copyWith(
        allStockIn: logs,
        isLoading: false,
      );
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat riwayat stok: $e',
      );
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(
      startDate: () => start,
      endDate: () => end,
    );
    _applyFilter();
  }

  void clearDateRange() {
    state = state.copyWith(
      startDate: () => null,
      endDate: () => null,
    );
    _applyFilter();
  }

  void _applyFilter() {
    List<StockIn> filtered = List.from(state.allStockIn);
    if (state.startDate != null && state.endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(state.startDate!);
      final endStr = DateFormat('yyyy-MM-dd').format(state.endDate!);
      filtered = filtered.where((s) {
        return s.tanggal.compareTo(startStr) >= 0 && s.tanggal.compareTo(endStr) <= 0;
      }).toList();
    } else if (state.startDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(state.startDate!);
      filtered = filtered.where((s) => s.tanggal.compareTo(startStr) >= 0).toList();
    }
    state = state.copyWith(filteredStockIn: filtered);
  }

  Future<bool> addStockIn({
    required String produkId,
    required int qty,
    required String tanggal,
    String type = 'in',
    String? catatan,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final now = DateTime.now();
      DateTime parsedDate;
      try {
        parsedDate = DateTime.parse(tanggal);
      } catch (_) {
        parsedDate = now;
      }
      final effectiveCreatedAt = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        now.hour,
        now.minute,
        now.second,
      );

      final log = StockIn(
        id: _uuid.v4(),
        produkId: produkId,
        type: type,
        qty: qty,
        tanggal: tanggal,
        catatan: catatan?.trim(),
        createdAt: effectiveCreatedAt,
      );

      await _repository.insertStockIn(log);
      await loadStockIn();
      
      // Crucial: refresh the product notifier to update product stock list!
      _ref.read(productNotifierProvider.notifier).loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mencatat mutasi stok: ${e.toString().replaceAll('Exception: ', '')}',
      );
      return false;
    }
  }
}

final stockNotifierProvider = StateNotifierProvider<StockNotifier, StockState>((ref) {
  final repo = ref.watch(stockRepositoryProvider);
  return StockNotifier(repo, ref);
});
