import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../domain/models/category.dart';
import '../domain/repositories/category_repository.dart';

class CategoryState {
  final List<Category> allCategories;
  final List<Category> filteredCategories;
  final String searchQuery;
  final String sortBy; // 'name_asc', 'name_desc'
  final int? statusFilter; // null = all, 1 = aktif, 0 = nonaktif
  final bool isLoading;
  final String? errorMessage;

  CategoryState({
    this.allCategories = const [],
    this.filteredCategories = const [],
    this.searchQuery = '',
    this.sortBy = 'name_asc',
    this.statusFilter,
    this.isLoading = false,
    this.errorMessage,
  });

  CategoryState copyWith({
    List<Category>? allCategories,
    List<Category>? filteredCategories,
    String? searchQuery,
    String? sortBy,
    int? statusFilter,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CategoryState(
      allCategories: allCategories ?? this.allCategories,
      filteredCategories: filteredCategories ?? this.filteredCategories,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      statusFilter: statusFilter !== null ? statusFilter : this.statusFilter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  final CategoryRepository _repository;
  final _uuid = const Uuid();

  CategoryNotifier(this._repository) : super(CategoryState()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final categories = await _repository.getAllCategories();
      state = state.copyWith(
        allCategories: categories,
        isLoading: false,
      );
      _applyFilterAndSort();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat kategori: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilterAndSort();
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
    _applyFilterAndSort();
  }

  void setStatusFilter(int? status) {
    // If status is null, we need to pass a sentinel value or handle it explicitly.
    // In copyWith, statusFilter is checked for null, so we'll construct it carefully.
    state = CategoryState(
      allCategories: state.allCategories,
      filteredCategories: state.filteredCategories,
      searchQuery: state.searchQuery,
      sortBy: state.sortBy,
      statusFilter: status,
      isLoading: state.isLoading,
      errorMessage: state.errorMessage,
    );
    _applyFilterAndSort();
  }

  void _applyFilterAndSort() {
    List<Category> filtered = List.from(state.allCategories);

    // Apply Search
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((c) => c.nama.toLowerCase().contains(query)).toList();
    }

    // Apply Status Filter
    if (state.statusFilter != null) {
      filtered = filtered.where((c) => c.status == state.statusFilter).toList();
    }

    // Apply Sort
    if (state.sortBy == 'name_asc') {
      filtered.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    } else if (state.sortBy == 'name_desc') {
      filtered.sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase()));
    }

    state = state.copyWith(filteredCategories: filtered);
  }

  Future<bool> addCategory(String name) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final exists = await _repository.isCategoryNameExists(name);
      if (exists) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Nama kategori sudah terdaftar',
        );
        return false;
      }

      final now = DateTime.now();
      final category = Category(
        id: _uuid.v4(),
        nama: name.trim(),
        status: 1,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insertCategory(category);
      await loadCategories();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menambah kategori: $e',
      );
      return false;
    }
  }

  Future<bool> updateCategory(String id, String name, int status) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final exists = await _repository.isCategoryNameExists(name, excludeId: id);
      if (exists) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Nama kategori sudah terdaftar',
        );
        return false;
      }

      final current = await _repository.getCategoryById(id);
      if (current == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Kategori tidak ditemukan');
        return false;
      }

      final updated = current.copyWith(
        nama: name.trim(),
        status: status,
        updatedAt: DateTime.now(),
      );

      await _repository.updateCategory(updated);
      await loadCategories();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui kategori: $e',
      );
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteCategory(id);
      await loadCategories();
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

// Provider definition
final categoryNotifierProvider = StateNotifierProvider<CategoryStateNotifier, CategoryState>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return CategoryStateNotifier(repo);
});

// Avoid duplicate class names, use standard naming
typedef CategoryStateNotifier = CategoryNotifier;
