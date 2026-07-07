import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../domain/models/product.dart';
import '../domain/repositories/product_repository.dart';

class ProductState {
  final List<Product> allProducts;
  final List<Product> filteredProducts;
  final String searchQuery;
  final String? categoryIdFilter;
  final int? statusFilter; // null = all, 1 = aktif, 0 = nonaktif
  final String sortBy; // 'name_asc', 'name_desc', 'price_asc', 'price_desc', 'stock_asc', 'stock_desc'
  final bool isLoading;
  final String? errorMessage;

  ProductState({
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.searchQuery = '',
    this.categoryIdFilter,
    this.statusFilter,
    this.sortBy = 'name_asc',
    this.isLoading = false,
    this.errorMessage,
  });

  ProductState copyWith({
    List<Product>? allProducts,
    List<Product>? filteredProducts,
    String? searchQuery,
    String? categoryIdFilter,
    int? statusFilter,
    String? sortBy,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProductState(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryIdFilter: categoryIdFilter != null ? categoryIdFilter : this.categoryIdFilter,
      statusFilter: statusFilter != null ? statusFilter : this.statusFilter,
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProductNotifier extends StateNotifier<ProductState> {
  final ProductRepository _repository;
  final _uuid = const Uuid();

  ProductNotifier(this._repository) : super(ProductState()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final products = await _repository.getAllProducts();
      state = state.copyWith(
        allProducts: products,
        isLoading: false,
      );
      _applyFilterAndSort();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat produk: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilterAndSort();
  }

  void setCategoryFilter(String? categoryId) {
    state = ProductState(
      allProducts: state.allProducts,
      filteredProducts: state.filteredProducts,
      searchQuery: state.searchQuery,
      categoryIdFilter: categoryId,
      statusFilter: state.statusFilter,
      sortBy: state.sortBy,
      isLoading: state.isLoading,
      errorMessage: state.errorMessage,
    );
    _applyFilterAndSort();
  }

  void setStatusFilter(int? status) {
    state = ProductState(
      allProducts: state.allProducts,
      filteredProducts: state.filteredProducts,
      searchQuery: state.searchQuery,
      categoryIdFilter: state.categoryIdFilter,
      statusFilter: status,
      sortBy: state.sortBy,
      isLoading: state.isLoading,
      errorMessage: state.errorMessage,
    );
    _applyFilterAndSort();
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
    _applyFilterAndSort();
  }

  void _applyFilterAndSort() {
    List<Product> filtered = List.from(state.allProducts);

    // Apply Search
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((p) => p.nama.toLowerCase().contains(query)).toList();
    }

    // Apply Category Filter
    if (state.categoryIdFilter != null && state.categoryIdFilter!.isNotEmpty) {
      filtered = filtered.where((p) => p.kategoriId == state.categoryIdFilter).toList();
    }

    // Apply Status Filter
    if (state.statusFilter != null) {
      filtered = filtered.where((p) => p.status == state.statusFilter).toList();
    }

    // Apply Sort
    if (state.sortBy == 'name_asc') {
      filtered.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    } else if (state.sortBy == 'name_desc') {
      filtered.sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase()));
    } else if (state.sortBy == 'price_asc') {
      filtered.sort((a, b) => a.harga.compareTo(b.harga));
    } else if (state.sortBy == 'price_desc') {
      filtered.sort((a, b) => b.harga.compareTo(a.harga));
    } else if (state.sortBy == 'stock_asc') {
      filtered.sort((a, b) => a.stok.compareTo(b.stok));
    } else if (state.sortBy == 'stock_desc') {
      filtered.sort((a, b) => b.stok.compareTo(a.stok));
    }

    state = state.copyWith(filteredProducts: filtered);
  }

  Future<bool> addProduct({
    required String nama,
    required String kategoriId,
    required double harga,
    required int stok,
    required int status,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final exists = await _repository.isProductNameExists(nama);
      if (exists) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Nama produk sudah terdaftar',
        );
        return false;
      }

      final now = DateTime.now();
      final product = Product(
        id: _uuid.v4(),
        kategoriId: kategoriId,
        nama: nama.trim(),
        harga: harga,
        stok: stok,
        status: status,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insertProduct(product);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menambah produk: $e',
      );
      return false;
    }
  }

  Future<bool> updateProduct({
    required String id,
    required String nama,
    required String kategoriId,
    required double harga,
    required int status,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final exists = await _repository.isProductNameExists(nama, excludeId: id);
      if (exists) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Nama produk sudah terdaftar',
        );
        return false;
      }

      final current = await _repository.getProductById(id);
      if (current == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Produk tidak ditemukan');
        return false;
      }

      final updated = current.copyWith(
        nama: nama.trim(),
        kategoriId: kategoriId,
        harga: harga,
        status: status,
        updatedAt: DateTime.now(),
      );

      await _repository.updateProduct(updated);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui produk: $e',
      );
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteProduct(id);
      await loadProducts();
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
final productNotifierProvider = StateNotifierProvider<ProductStateNotifier, ProductState>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return ProductStateNotifier(repo);
});

typedef ProductStateNotifier = ProductNotifier;
