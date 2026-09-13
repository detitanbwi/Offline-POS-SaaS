import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../category/domain/models/category.dart';
import '../../category/domain/repositories/category_repository.dart';
import '../../category/application/category_notifier.dart';
import '../../product/domain/models/product.dart';
import '../../product/domain/repositories/product_repository.dart';
import '../../product/application/product_notifier.dart';
import '../../table/domain/models/table.dart';
import '../../table/domain/repositories/table_repository.dart';
import '../../table/application/table_notifier.dart';
import '../../payment_method/domain/models/payment_method.dart';
import '../../payment_method/domain/repositories/payment_method_repository.dart';
import '../../payment_method/application/payment_method_notifier.dart';
import '../../cashier/domain/models/cashier.dart';
import '../../cashier/domain/repositories/cashier_repository.dart';
import '../../cashier/application/cashier_notifier.dart';
import '../../pos/domain/models/online_platform.dart';
import '../../pos/domain/repositories/online_platform_repository.dart';
import '../../pos/application/online_platform_notifier.dart';

class TrashBinState {
  final List<Product> deletedProducts;
  final List<Category> deletedCategories;
  final List<TableModel> deletedTables;
  final List<PaymentMethod> deletedPaymentMethods;
  final List<CashierModel> deletedCashiers;
  final List<OnlinePlatformModel> deletedPlatforms;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const TrashBinState({
    this.deletedProducts = const [],
    this.deletedCategories = const [],
    this.deletedTables = const [],
    this.deletedPaymentMethods = const [],
    this.deletedCashiers = const [],
    this.deletedPlatforms = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  int get totalDeletedCount =>
      deletedProducts.length +
      deletedCategories.length +
      deletedTables.length +
      deletedPaymentMethods.length +
      deletedCashiers.length +
      deletedPlatforms.length;

  TrashBinState copyWith({
    List<Product>? deletedProducts,
    List<Category>? deletedCategories,
    List<TableModel>? deletedTables,
    List<PaymentMethod>? deletedPaymentMethods,
    List<CashierModel>? deletedCashiers,
    List<OnlinePlatformModel>? deletedPlatforms,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return TrashBinState(
      deletedProducts: deletedProducts ?? this.deletedProducts,
      deletedCategories: deletedCategories ?? this.deletedCategories,
      deletedTables: deletedTables ?? this.deletedTables,
      deletedPaymentMethods: deletedPaymentMethods ?? this.deletedPaymentMethods,
      deletedCashiers: deletedCashiers ?? this.deletedCashiers,
      deletedPlatforms: deletedPlatforms ?? this.deletedPlatforms,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class TrashBinNotifier extends StateNotifier<TrashBinState> {
  final Ref? _ref;
  final ProductRepository _productRepo;
  final CategoryRepository _categoryRepo;
  final TableRepository _tableRepo;
  final PaymentMethodRepository _paymentMethodRepo;
  final CashierRepository _cashierRepo;
  final OnlinePlatformRepository _platformRepo;

  TrashBinNotifier({
    Ref? ref,
    required ProductRepository productRepo,
    required CategoryRepository categoryRepo,
    required TableRepository tableRepo,
    required PaymentMethodRepository paymentMethodRepo,
    required CashierRepository cashierRepo,
    required OnlinePlatformRepository platformRepo,
  })  : _ref = ref,
        _productRepo = productRepo,
        _categoryRepo = categoryRepo,
        _tableRepo = tableRepo,
        _paymentMethodRepo = paymentMethodRepo,
        _cashierRepo = cashierRepo,
        _platformRepo = platformRepo,
        super(const TrashBinState()) {
    loadAll();
  }

  Future<void> loadAll({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
    try {
      final prods = await _productRepo.getDeletedProducts();
      final cats = await _categoryRepo.getDeletedCategories();
      final tbls = await _tableRepo.getDeletedTables();
      final pms = await _paymentMethodRepo.getDeletedPaymentMethods();
      final cashiers = await _cashierRepo.getDeletedCashiers();
      final platforms = await _platformRepo.getDeletedPlatforms();

      state = state.copyWith(
        deletedProducts: prods,
        deletedCategories: cats,
        deletedTables: tbls,
        deletedPaymentMethods: pms,
        deletedCashiers: cashiers,
        deletedPlatforms: platforms,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat data tempat sampah: $e',
      );
    }
  }

  // --- Product ---
  Future<bool> restoreProduct(String id) async {
    try {
      await _productRepo.restoreProduct(id);
      await loadAll(showLoading: false);
      _ref?.read(productNotifierProvider.notifier).loadProducts();
      state = state.copyWith(successMessage: 'Produk berhasil dipulihkan!');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: 'Gagal memulihkan produk: $clean');
      return false;
    }
  }

  Future<bool> permanentDeleteProduct(String id) async {
    try {
      await _productRepo.permanentDeleteProduct(id);
      await loadAll(showLoading: false);
      state = state.copyWith(successMessage: 'Produk berhasil dihapus permanen.');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: clean);
      return false;
    }
  }

  // --- Category ---
  Future<bool> restoreCategory(String id) async {
    try {
      await _categoryRepo.restoreCategory(id);
      await loadAll(showLoading: false);
      _ref?.read(categoryNotifierProvider.notifier).loadCategories();
      state = state.copyWith(successMessage: 'Kategori berhasil dipulihkan!');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: 'Gagal memulihkan kategori: $clean');
      return false;
    }
  }

  Future<bool> permanentDeleteCategory(String id) async {
    try {
      await _categoryRepo.permanentDeleteCategory(id);
      await loadAll(showLoading: false);
      state = state.copyWith(successMessage: 'Kategori berhasil dihapus permanen.');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: clean);
      return false;
    }
  }

  // --- Table ---
  Future<bool> restoreTable(String id) async {
    try {
      await _tableRepo.restoreTable(id);
      await loadAll(showLoading: false);
      _ref?.read(tableNotifierProvider.notifier).loadTables();
      state = state.copyWith(successMessage: 'Meja berhasil dipulihkan!');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: 'Gagal memulihkan meja: $clean');
      return false;
    }
  }

  Future<bool> permanentDeleteTable(String id) async {
    try {
      await _tableRepo.permanentDeleteTable(id);
      await loadAll(showLoading: false);
      state = state.copyWith(successMessage: 'Meja berhasil dihapus permanen.');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: clean);
      return false;
    }
  }

  // --- Payment Method ---
  Future<bool> restorePaymentMethod(String id) async {
    try {
      await _paymentMethodRepo.restorePaymentMethod(id);
      await loadAll(showLoading: false);
      _ref?.read(paymentMethodNotifierProvider.notifier).loadPaymentMethods();
      state = state.copyWith(successMessage: 'Metode pembayaran berhasil dipulihkan!');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: 'Gagal memulihkan metode pembayaran: $clean');
      return false;
    }
  }

  Future<bool> permanentDeletePaymentMethod(String id) async {
    try {
      await _paymentMethodRepo.permanentDeletePaymentMethod(id);
      await loadAll(showLoading: false);
      state = state.copyWith(successMessage: 'Metode pembayaran berhasil dihapus permanen.');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: clean);
      return false;
    }
  }

  // --- Cashier ---
  Future<bool> restoreCashier(String id) async {
    try {
      await _cashierRepo.restoreCashier(id);
      await loadAll(showLoading: false);
      _ref?.read(cashierNotifierProvider.notifier).loadCashiers();
      state = state.copyWith(successMessage: 'Kasir berhasil dipulihkan!');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: 'Gagal memulihkan kasir: $clean');
      return false;
    }
  }

  Future<bool> permanentDeleteCashier(String id) async {
    try {
      await _cashierRepo.permanentDeleteCashier(id);
      await loadAll(showLoading: false);
      state = state.copyWith(successMessage: 'Kasir berhasil dihapus permanen.');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: clean);
      return false;
    }
  }

  // --- Online Platform ---
  Future<bool> restorePlatform(String id) async {
    try {
      await _platformRepo.restorePlatform(id);
      await loadAll(showLoading: false);
      _ref?.read(onlinePlatformNotifierProvider.notifier).loadPlatforms();
      state = state.copyWith(successMessage: 'Platform online berhasil dipulihkan!');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: 'Gagal memulihkan platform: $clean');
      return false;
    }
  }

  Future<bool> permanentDeletePlatform(String id) async {
    try {
      await _platformRepo.permanentDeletePlatform(id);
      await loadAll(showLoading: false);
      state = state.copyWith(successMessage: 'Platform online berhasil dihapus permanen.');
      return true;
    } catch (e) {
      final clean = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(errorMessage: clean);
      return false;
    }
  }
}

final trashBinNotifierProvider = StateNotifierProvider<TrashBinNotifier, TrashBinState>((ref) {
  return TrashBinNotifier(
    ref: ref,
    productRepo: ref.watch(productRepositoryProvider),
    categoryRepo: ref.watch(categoryRepositoryProvider),
    tableRepo: ref.watch(tableRepositoryProvider),
    paymentMethodRepo: ref.watch(paymentMethodRepositoryProvider),
    cashierRepo: ref.watch(cashierRepositoryProvider),
    platformRepo: ref.watch(onlinePlatformRepositoryProvider),
  );
});
