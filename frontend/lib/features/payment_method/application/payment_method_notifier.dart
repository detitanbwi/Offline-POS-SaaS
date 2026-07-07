import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../domain/models/payment_method.dart';
import '../domain/repositories/payment_method_repository.dart';

class PaymentMethodState {
  final List<PaymentMethod> allMethods;
  final List<PaymentMethod> filteredMethods;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  PaymentMethodState({
    this.allMethods = const [],
    this.filteredMethods = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  PaymentMethodState copyWith({
    List<PaymentMethod>? allMethods,
    List<PaymentMethod>? filteredMethods,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PaymentMethodState(
      allMethods: allMethods ?? this.allMethods,
      filteredMethods: filteredMethods ?? this.filteredMethods,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PaymentMethodNotifier extends StateNotifier<PaymentMethodState> {
  final PaymentMethodRepository _repository;
  final _uuid = const Uuid();

  PaymentMethodNotifier(this._repository) : super(PaymentMethodState()) {
    loadPaymentMethods();
  }

  Future<void> loadPaymentMethods() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final methods = await _repository.getAllPaymentMethods();
      state = state.copyWith(
        allMethods: methods,
        isLoading: false,
      );
      _applyFilter();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat metode pembayaran: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilter();
  }

  void _applyFilter() {
    List<PaymentMethod> filtered = List.from(state.allMethods);
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((p) => p.nama.toLowerCase().contains(query)).toList();
    }
    state = state.copyWith(filteredMethods: filtered);
  }

  Future<bool> addPaymentMethod(String name) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final exists = await _repository.isPaymentMethodNameExists(name);
      if (exists) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Metode pembayaran sudah terdaftar',
        );
        return false;
      }

      final now = DateTime.now();
      final method = PaymentMethod(
        id: 'pm-${_uuid.v4()}',
        nama: name.trim(),
        icon: 'payment', // Default text icon placeholder as agreed
        aktif: 1,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insertPaymentMethod(method);
      await loadPaymentMethods();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menambah metode pembayaran: $e',
      );
      return false;
    }
  }

  Future<bool> updatePaymentMethod(String id, String name, int status) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final exists = await _repository.isPaymentMethodNameExists(name, excludeId: id);
      if (exists) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Metode pembayaran sudah terdaftar',
        );
        return false;
      }

      final current = await _repository.getPaymentMethodById(id);
      if (current == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Metode pembayaran tidak ditemukan');
        return false;
      }

      final updated = current.copyWith(
        nama: name.trim(),
        aktif: status,
        updatedAt: DateTime.now(),
      );

      await _repository.updatePaymentMethod(updated);
      await loadPaymentMethods();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui metode pembayaran: $e',
      );
      return false;
    }
  }

  Future<bool> togglePaymentMethodStatus(String id, bool active) async {
    final current = await _repository.getPaymentMethodById(id);
    if (current == null) return false;

    // Don't allow disabling default cash method
    if (id == 'pm-tunai' && !active) {
      state = state.copyWith(errorMessage: 'Metode pembayaran Tunai default tidak dapat dinonaktifkan.');
      return false;
    }

    try {
      final updated = current.copyWith(
        aktif: active ? 1 : 0,
        updatedAt: DateTime.now(),
      );
      await _repository.updatePaymentMethod(updated);
      await loadPaymentMethods();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal memperbarui status: $e');
      return false;
    }
  }

  Future<bool> deletePaymentMethod(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deletePaymentMethod(id);
      await loadPaymentMethods();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final paymentMethodNotifierProvider =
    StateNotifierProvider<PaymentMethodNotifier, PaymentMethodState>((ref) {
  final repo = ref.watch(paymentMethodRepositoryProvider);
  return PaymentMethodNotifier(repo);
});
