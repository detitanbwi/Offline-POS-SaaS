import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../domain/models/cashier.dart';
import '../domain/repositories/cashier_repository.dart';

class CashierState {
  final List<CashierModel> allCashiers;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  CashierState({
    this.allCashiers = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  CashierState copyWith({
    List<CashierModel>? allCashiers,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return CashierState(
      allCashiers: allCashiers ?? this.allCashiers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class CashierNotifier extends StateNotifier<CashierState> {
  final CashierRepository _repository;
  final _uuid = const Uuid();

  CashierNotifier(this._repository) : super(CashierState()) {
    loadCashiers();
  }

  String _hashPIN(String pin) {
    const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
    var bytes = utf8.encode(pin + salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> loadCashiers() async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final cashiers = await _repository.getAllCashiers();
      state = state.copyWith(allCashiers: cashiers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data kasir: $e');
    }
  }

  Future<bool> addCashier(String name, String username, String pin) async {
    final trimmedName = name.trim();
    final trimmedUsername = username.trim().toLowerCase().replaceAll(' ', '_');
    if (trimmedName.isEmpty) {
      state = state.copyWith(errorMessage: 'Nama kasir tidak boleh kosong.');
      return false;
    }
    if (trimmedUsername.isEmpty) {
      state = state.copyWith(errorMessage: 'Username kasir tidak boleh kosong.');
      return false;
    }
    if (pin.length != 6) {
      state = state.copyWith(errorMessage: 'PIN harus tepat 6 digit.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      if (await _repository.isNameExists(trimmedName)) {
        state = state.copyWith(isLoading: false, errorMessage: 'Nama kasir "$trimmedName" sudah terdaftar.');
        return false;
      }
      if (await _repository.isUsernameExists(trimmedUsername)) {
        state = state.copyWith(isLoading: false, errorMessage: 'Username "$trimmedUsername" sudah terdaftar.');
        return false;
      }

      final hashedPin = _hashPIN(pin);
      if (await _repository.isPinExists(hashedPin)) {
        state = state.copyWith(isLoading: false, errorMessage: 'PIN 6-digit ini sudah digunakan oleh kasir lain.');
        return false;
      }

      final isOwner = state.allCashiers.isEmpty ? 1 : 0;
      final newCashier = CashierModel(
        id: _uuid.v4(),
        nama: trimmedName,
        username: trimmedUsername,
        pin: hashedPin,
        status: 1,
        isDeleted: 0,
        isOwner: isOwner,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.saveCashier(newCashier);
      await loadCashiers();
      state = state.copyWith(successMessage: 'Kasir baru berhasil didaftarkan.');
      return true;
    } catch (e) {
      String cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal mendaftarkan kasir: $cleanErr');
      return false;
    }
  }

  Future<bool> updateCashier(String id, String name, String username, String? newPin) async {
    final trimmedName = name.trim();
    final trimmedUsername = username.trim().toLowerCase().replaceAll(' ', '_');
    if (trimmedName.isEmpty) {
      state = state.copyWith(errorMessage: 'Nama kasir tidak boleh kosong.');
      return false;
    }
    if (trimmedUsername.isEmpty) {
      state = state.copyWith(errorMessage: 'Username kasir tidak boleh kosong.');
      return false;
    }
    if (newPin != null && newPin.isNotEmpty && newPin.length != 6) {
      state = state.copyWith(errorMessage: 'PIN baru harus tepat 6 digit.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final existing = await _repository.getCashierById(id);
      if (existing == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Kasir tidak ditemukan.');
        return false;
      }

      if (await _repository.isNameExists(trimmedName, excludeId: id)) {
        state = state.copyWith(isLoading: false, errorMessage: 'Nama kasir "$trimmedName" sudah terdaftar.');
        return false;
      }
      if (await _repository.isUsernameExists(trimmedUsername, excludeId: id)) {
        state = state.copyWith(isLoading: false, errorMessage: 'Username "$trimmedUsername" sudah terdaftar.');
        return false;
      }

      String finalPin = existing.pin;
      if (newPin != null && newPin.isNotEmpty) {
        finalPin = _hashPIN(newPin);
        if (await _repository.isPinExists(finalPin, excludeId: id)) {
          state = state.copyWith(isLoading: false, errorMessage: 'PIN 6-digit ini sudah digunakan oleh kasir lain.');
          return false;
        }
      }

      final updated = existing.copyWith(
        nama: trimmedName,
        username: trimmedUsername,
        pin: finalPin,
        updatedAt: DateTime.now(),
      );

      await _repository.saveCashier(updated);
      await loadCashiers();
      state = state.copyWith(successMessage: 'Data kasir berhasil diperbarui.');
      return true;
    } catch (e) {
      String cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memperbarui kasir: $cleanErr');
      return false;
    }
  }

  Future<void> toggleStatus(String id, int currentStatus) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final newStatus = currentStatus == 1 ? 0 : 1;
      await _repository.updateStatus(id, newStatus);
      await loadCashiers();
      state = state.copyWith(successMessage: 'Status kasir berhasil diubah.');
    } catch (e) {
      String cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal mengubah status kasir: $cleanErr');
    }
  }

  Future<void> deleteCashier(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _repository.softDelete(id);
      await loadCashiers();
      state = state.copyWith(successMessage: 'Akun kasir berhasil dihapus.');
    } catch (e) {
      String cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus kasir: $cleanErr');
    }
  }
}

final cashierNotifierProvider = StateNotifierProvider<CashierNotifier, CashierState>((ref) {
  final repo = ref.watch(cashierRepositoryProvider);
  return CashierNotifier(repo);
});
