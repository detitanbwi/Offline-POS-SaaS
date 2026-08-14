import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../table/domain/models/table.dart';
import '../../table/domain/repositories/table_repository.dart';

class TableState {
  final List<TableModel> allTables;
  final bool isLoading;
  final String? errorMessage;

  TableState({
    this.allTables = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  TableState copyWith({
    List<TableModel>? allTables,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TableState(
      allTables: allTables ?? this.allTables,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TableNotifier extends StateNotifier<TableState> {
  final TableRepository _repository;
  final _uuid = const Uuid();

  TableNotifier(this._repository) : super(TableState()) {
    _initLoad();
  }

  Future<void> _initLoad() async {
    await loadTables();
  }

  Future<void> loadTables() async {
    // Memberi jeda 300ms agar animasi transisi layar selesai
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final tables = await _repository.getAllTables();
      state = state.copyWith(
        allTables: tables,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat daftar meja: $e',
      );
    }
  }

  Future<bool> createTable({required String nama, required String nomor}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Validasi keunikan nama
      final isNameDup = await _repository.isTableNameExists(nama);
      if (isNameDup) {
        state = state.copyWith(isLoading: false, errorMessage: 'Nama meja "$nama" sudah digunakan.');
        return false;
      }

      // Validasi keunikan nomor
      final isNumDup = await _repository.isTableNumberExists(nomor);
      if (isNumDup) {
        state = state.copyWith(isLoading: false, errorMessage: 'Nomor meja "$nomor" sudah digunakan.');
        return false;
      }

      final table = TableModel(
        id: _uuid.v4(),
        nama: nama,
        nomor: nomor,
        status: 0, // Default Kosong
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.saveTable(table);
      await loadTables();
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menambah meja: $cleanErr');
      return false;
    }
  }

  Future<bool> generateMultipleTables(int count) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final existingTables = await _repository.getAllTables();
      final existingNames = existingTables.map((t) => t.nama.toLowerCase()).toSet();
      final existingNumbers = existingTables.map((t) => t.nomor).toSet();

      int generated = 0;
      int currentNum = 1;

      while (generated < count) {
        final numberStr = currentNum.toString().padLeft(2, '0');
        final nameStr = 'Meja $numberStr';

        if (!existingNames.contains(nameStr.toLowerCase()) && !existingNumbers.contains(numberStr)) {
          final table = TableModel(
            id: _uuid.v4(),
            nama: nameStr,
            nomor: numberStr,
            status: 0, // Default Kosong
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _repository.saveTable(table);
          generated++;
        }
        currentNum++;
      }
      await loadTables();
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal men-generate meja: $cleanErr');
      return false;
    }
  }

  Future<bool> updateTable({required String id, required String nama, required String nomor, required int status}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Validasi keunikan nama
      final isNameDup = await _repository.isTableNameExists(nama, excludeId: id);
      if (isNameDup) {
        state = state.copyWith(isLoading: false, errorMessage: 'Nama meja "$nama" sudah digunakan.');
        return false;
      }

      // Validasi keunikan nomor
      final isNumDup = await _repository.isTableNumberExists(nomor, excludeId: id);
      if (isNumDup) {
        state = state.copyWith(isLoading: false, errorMessage: 'Nomor meja "$nomor" sudah digunakan.');
        return false;
      }

      final existing = await _repository.getTableById(id);
      if (existing == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Meja tidak ditemukan.');
        return false;
      }

      final updated = existing.copyWith(
        nama: nama,
        nomor: nomor,
        status: status,
        updatedAt: DateTime.now(),
      );

      await _repository.saveTable(updated);
      await loadTables();
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memperbarui meja: $cleanErr');
      return false;
    }
  }

  Future<bool> deleteTable(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteTable(id);
      await loadTables();
      return true;
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        errorMessage: cleanErr,
      );
      return false;
    }
  }

  Future<void> updateStatus(String id, int status) async {
    try {
      await _repository.updateTableStatus(id, status);
      await loadTables();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal memperbarui status meja: $e');
    }
  }
}

final tableNotifierProvider = StateNotifierProvider<TableNotifier, TableState>((ref) {
  final repository = ref.watch(tableRepositoryProvider);
  return TableNotifier(repository);
});
