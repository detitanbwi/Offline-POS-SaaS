import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../domain/models/online_platform.dart';
import '../domain/repositories/online_platform_repository.dart';

class OnlinePlatformState {
  final List<OnlinePlatformModel> platforms;
  final bool isLoading;
  final String? errorMessage;

  OnlinePlatformState({
    this.platforms = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  OnlinePlatformState copyWith({
    List<OnlinePlatformModel>? platforms,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OnlinePlatformState(
      platforms: platforms ?? this.platforms,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class OnlinePlatformNotifier extends StateNotifier<OnlinePlatformState> {
  final OnlinePlatformRepository _repository;

  OnlinePlatformNotifier(this._repository) : super(OnlinePlatformState()) {
    loadPlatforms();
  }

  Future<void> loadPlatforms() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final platforms = await _repository.getAllPlatforms();
      state = state.copyWith(platforms: platforms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat platform online: $e');
    }
  }

  Future<bool> addPlatform(String nama) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.addPlatform(nama);
      await loadPlatforms();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menambah platform: $e');
      return false;
    }
  }

  Future<bool> updatePlatform(String id, String nama, int aktif) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updatePlatform(id, nama, aktif);
      await loadPlatforms();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal mengubah platform: $e');
      return false;
    }
  }

  Future<bool> deletePlatform(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deletePlatform(id);
      await loadPlatforms();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus platform: $e');
      return false;
    }
  }
}

final onlinePlatformNotifierProvider = StateNotifierProvider<OnlinePlatformNotifier, OnlinePlatformState>((ref) {
  final repository = ref.watch(onlinePlatformRepositoryProvider);
  return OnlinePlatformNotifier(repository);
});
