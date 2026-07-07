import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../product/application/product_notifier.dart';
import '../domain/models/stock_in.dart';
import '../domain/repositories/stock_repository.dart';

class StockState {
  final List<StockIn> allStockIn;
  final List<StockIn> filteredStockIn;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  StockState({
    this.allStockIn = const [],
    this.filteredStockIn = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  StockState copyWith({
    List<StockIn>? allStockIn,
    List<StockIn>? filteredStockIn,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return StockState(
      allStockIn: allStockIn ?? this.allStockIn,
      filteredStockIn: filteredStockIn ?? this.filteredStockIn,
      searchQuery: searchQuery ?? this.searchQuery,
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
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final logs = await _repository.getAllStockIn();
      state = state.copyWith(
        allStockIn: logs,
        isLoading: false,
      );
      _applyFilter();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat riwayat stok: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilter();
  }

  void _applyFilter() {
    List<StockIn> filtered = List.from(state.allStockIn);
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered
          .where((s) => (s.produkNama?.toLowerCase().contains(query) ?? false) || (s.catatan?.toLowerCase().contains(query) ?? false))
          .toList();
    }
    state = state.copyWith(filteredStockIn: filtered);
  }

  Future<bool> addStockIn({
    required String produkId,
    required int qty,
    required String tanggal,
    String? catatan,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final log = StockIn(
        id: _uuid.v4(),
        produkId: produkId,
        qty: qty,
        tanggal: tanggal,
        catatan: catatan?.trim(),
        createdAt: DateTime.now(),
      );

      await _repository.insertStockIn(log);
      await loadStockIn();
      
      // Crucial: refresh the product notifier to update product stock list!
      _ref.read(productNotifierProvider.notifier).loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mencatat stok masuk: $e',
      );
      return false;
    }
  }
}

final stockNotifierProvider = StateNotifierProvider<StockNotifier, StockState>((ref) {
  final repo = ref.watch(stockRepositoryProvider);
  return StockNotifier(repo, ref);
});
