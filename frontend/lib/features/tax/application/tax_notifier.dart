import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../domain/models/tax_setting.dart';
import '../domain/repositories/tax_repository.dart';

class TaxState {
  final TaxSetting? taxSetting;
  final bool isLoading;
  final String? errorMessage;

  TaxState({
    this.taxSetting,
    this.isLoading = false,
    this.errorMessage,
  });

  TaxState copyWith({
    TaxSetting? taxSetting,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TaxState(
      taxSetting: taxSetting ?? this.taxSetting,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TaxNotifier extends StateNotifier<TaxState> {
  final TaxRepository _repository;

  TaxNotifier(this._repository) : super(TaxState()) {
    loadTaxSetting();
  }

  Future<void> loadTaxSetting() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final setting = await _repository.getTaxSetting();
      if (!mounted) return;
      state = state.copyWith(
        taxSetting: setting,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat pengaturan pajak: $e',
      );
    }
  }

  Future<bool> updateTaxSetting(bool enable, double percentage) async {
    final current = state.taxSetting;
    return updateTaxAndServiceSetting(
      taxEnable: enable,
      taxPercentage: percentage,
      serviceEnable: current?.isServiceChargeEnabled ?? false,
      servicePercentage: current?.serviceChargePercentage ?? 0.0,
      serviceAfterTax: current?.isServiceChargeAfterTax ?? false,
    );
  }

  Future<bool> updateTaxAndServiceSetting({
    required bool taxEnable,
    required double taxPercentage,
    required bool serviceEnable,
    required double servicePercentage,
    required bool serviceAfterTax,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final setting = TaxSetting(
        id: 1,
        enable: taxEnable ? 1 : 0,
        percentage: taxPercentage,
        serviceChargeEnable: serviceEnable ? 1 : 0,
        serviceChargePercentage: servicePercentage,
        serviceChargeAfterTax: serviceAfterTax ? 1 : 0,
        updatedAt: DateTime.now(),
      );
      await _repository.updateTaxSetting(setting);
      if (!mounted) return true;
      state = state.copyWith(
        taxSetting: setting,
        isLoading: false,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mengubah pengaturan pajak & service charge: $e',
      );
      return false;
    }
  }
}

final taxNotifierProvider = StateNotifierProvider<TaxNotifier, TaxState>((ref) {
  final repo = ref.watch(taxRepositoryProvider);
  return TaxNotifier(repo);
});
