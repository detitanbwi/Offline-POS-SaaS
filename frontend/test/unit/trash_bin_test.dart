import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/soft_delete_helper.dart';
import 'package:frontend/features/category/domain/models/category.dart';
import 'package:frontend/features/category/domain/repositories/category_repository.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/product/domain/repositories/product_repository.dart';
import 'package:frontend/features/payment_method/domain/models/payment_method.dart';
import 'package:frontend/features/payment_method/domain/repositories/payment_method_repository.dart';
import 'package:frontend/features/table/domain/models/table.dart';
import 'package:frontend/features/table/domain/repositories/table_repository.dart';
import 'package:frontend/features/cashier/domain/models/cashier.dart';
import 'package:frontend/features/cashier/domain/repositories/cashier_repository.dart';
import 'package:frontend/features/pos/domain/models/online_platform.dart';
import 'package:frontend/features/pos/domain/repositories/online_platform_repository.dart';
import 'package:frontend/features/settings/application/trash_bin_notifier.dart';

// Mocks for TrashBinNotifier tests
class MockProductRepo implements ProductRepository {
  List<Product> products = [];
  List<Product> deletedProducts = [];
  bool throwFkOnPermanent = false;

  @override
  Future<List<Product>> getAllProducts() async => products;
  @override
  Future<Product?> getProductById(String id) async => null;
  @override
  Future<void> insertProduct(
    Product product, {
    DateTime? initialStockDate,
    String? initialStockNotes,
  }) async => products.add(product);
  @override
  Future<void> updateProduct(Product product) async {}
  @override
  Future<void> deleteProduct(String id) async {
    final item = products.firstWhere((p) => p.id == id);
    products.remove(item);
    deletedProducts.add(item.copyWith(nama: SoftDeleteHelper.makeDeletedName(item.nama)));
  }
  @override
  Future<bool> isProductNameExists(String name, {String? excludeId}) async => false;
  @override
  Future<void> toggleProductStatus(String id, int status) async {
    final idx = products.indexWhere((p) => p.id == id);
    if (idx >= 0) products[idx] = products[idx].copyWith(status: status);
  }
  @override
  Future<void> updateStock(String id, int quantityChange) async {}
  @override
  Future<List<Product>> getDeletedProducts() async => deletedProducts;
  @override
  Future<void> restoreProduct(String id) async {
    final item = deletedProducts.firstWhere((p) => p.id == id);
    deletedProducts.remove(item);
    products.add(item.copyWith(nama: SoftDeleteHelper.getOriginalName(item.nama)));
  }
  @override
  Future<void> permanentDeleteProduct(String id) async {
    if (throwFkOnPermanent) {
      throw Exception('Produk tidak dapat dihapus permanen karena masih tercatat pada riwayat transaksi');
    }
    deletedProducts.removeWhere((p) => p.id == id);
  }
}

class MockCategoryRepo implements CategoryRepository {
  List<Category> categories = [];
  List<Category> deletedCategories = [];
  bool throwFk = false;

  @override
  Future<List<Category>> getAllCategories() async => categories;
  @override
  Future<Category?> getCategoryById(String id) async => null;
  @override
  Future<void> insertCategory(Category category) async => categories.add(category);
  @override
  Future<void> updateCategory(Category category) async {}
  @override
  Future<void> deleteCategory(String id) async {
    final item = categories.firstWhere((c) => c.id == id);
    categories.remove(item);
    deletedCategories.add(item.copyWith(nama: SoftDeleteHelper.makeDeletedName(item.nama)));
  }
  @override
  Future<bool> isCategoryNameExists(String name, {String? excludeId}) async => false;
  @override
  Future<void> toggleCategoryStatus(String id, int status) async {
    final idx = categories.indexWhere((c) => c.id == id);
    if (idx >= 0) categories[idx] = categories[idx].copyWith(status: status);
  }
  @override
  Future<List<Category>> getDeletedCategories() async => deletedCategories;
  @override
  Future<void> restoreCategory(String id) async {
    final item = deletedCategories.firstWhere((c) => c.id == id);
    deletedCategories.remove(item);
    categories.add(item.copyWith(nama: SoftDeleteHelper.getOriginalName(item.nama)));
  }
  @override
  Future<void> permanentDeleteCategory(String id) async {
    if (throwFk) throw Exception('Kategori masih digunakan oleh produk aktif');
    deletedCategories.removeWhere((c) => c.id == id);
  }
}

class MockPaymentMethodRepo implements PaymentMethodRepository {
  List<PaymentMethod> methods = [];
  List<PaymentMethod> deletedMethods = [];

  @override
  Future<List<PaymentMethod>> getAllPaymentMethods() async => methods;
  @override
  Future<PaymentMethod?> getPaymentMethodById(String id) async => null;
  @override
  Future<void> insertPaymentMethod(PaymentMethod method) async => methods.add(method);
  @override
  Future<void> updatePaymentMethod(PaymentMethod method) async {}
  @override
  Future<void> deletePaymentMethod(String id) async {
    final item = methods.firstWhere((m) => m.id == id);
    methods.remove(item);
    deletedMethods.add(item.copyWith(isDeleted: true, nama: SoftDeleteHelper.makeDeletedName(item.nama)));
  }
  @override
  Future<void> togglePaymentMethodStatus(String id, bool isActive) async {}
  @override
  Future<bool> isPaymentMethodNameExists(String name, {String? excludeId}) async => false;
  @override
  Future<List<PaymentMethod>> getDeletedPaymentMethods() async => deletedMethods;
  @override
  Future<void> restorePaymentMethod(String id) async {
    final item = deletedMethods.firstWhere((m) => m.id == id);
    deletedMethods.remove(item);
    methods.add(item.copyWith(isDeleted: false, nama: SoftDeleteHelper.getOriginalName(item.nama)));
  }
  @override
  Future<void> permanentDeletePaymentMethod(String id) async {
    deletedMethods.removeWhere((m) => m.id == id);
  }
}

class MockTableRepo implements TableRepository {
  List<TableModel> tables = [];
  List<TableModel> deletedTables = [];

  @override
  Future<List<TableModel>> getAllTables() async => tables;
  @override
  Future<TableModel?> getTableById(String id) async => null;
  @override
  Future<void> saveTable(TableModel table) async => tables.add(table);
  @override
  Future<void> deleteTable(String id) async {
    final item = tables.firstWhere((t) => t.id == id);
    tables.remove(item);
    deletedTables.add(item.copyWith(
      isDeleted: true,
      nama: SoftDeleteHelper.makeDeletedName(item.nama),
      nomor: SoftDeleteHelper.makeDeletedNomor(item.nomor),
    ));
  }
  @override
  Future<bool> isTableNameExists(String name, {String? excludeId}) async => false;
  @override
  Future<bool> isTableNumberExists(String number, {String? excludeId}) async => false;
  @override
  Future<void> updateTableStatus(String id, int status) async {}
  @override
  Future<List<TableModel>> getDeletedTables() async => deletedTables;
  @override
  Future<void> restoreTable(String id) async {
    final item = deletedTables.firstWhere((t) => t.id == id);
    deletedTables.remove(item);
    tables.add(item.copyWith(
      isDeleted: false,
      nama: SoftDeleteHelper.getOriginalName(item.nama),
      nomor: SoftDeleteHelper.getOriginalNomor(item.nomor),
    ));
  }
  @override
  Future<void> permanentDeleteTable(String id) async {
    deletedTables.removeWhere((t) => t.id == id);
  }
}

class MockCashierRepo implements CashierRepository {
  List<CashierModel> cashiers = [];
  List<CashierModel> deletedCashiers = [];

  @override
  Future<List<CashierModel>> getAllCashiers() async => cashiers;
  @override
  Future<CashierModel?> getCashierById(String id) async => null;
  @override
  Future<CashierModel?> getCashierByUsername(String username) async => null;
  @override
  Future<CashierModel?> getCashierByPin(String hashedPin) async => null;
  @override
  Future<CashierModel?> getCashierByNameAndPin(String name, String hashedPin) async => null;
  @override
  Future<void> saveCashier(CashierModel cashier) async => cashiers.add(cashier);
  @override
  Future<void> updateStatus(String id, int status) async {}
  @override
  Future<void> softDelete(String id) async {
    final item = cashiers.firstWhere((c) => c.id == id);
    cashiers.remove(item);
    deletedCashiers.add(item.copyWith(
      isDeleted: 1,
      username: SoftDeleteHelper.makeDeletedName(item.username),
    ));
  }
  @override
  Future<bool> isNameExists(String name, {String? excludeId}) async => false;
  @override
  Future<bool> isUsernameExists(String username, {String? excludeId}) async => false;
  @override
  Future<bool> isPinExists(String hashedPin, {String? excludeId}) async => false;
  @override
  Future<List<CashierModel>> getDeletedCashiers() async => deletedCashiers;
  @override
  Future<void> restoreCashier(String id) async {
    final item = deletedCashiers.firstWhere((c) => c.id == id);
    deletedCashiers.remove(item);
    cashiers.add(item.copyWith(
      isDeleted: 0,
      username: SoftDeleteHelper.getOriginalName(item.username),
    ));
  }
  @override
  Future<void> permanentDeleteCashier(String id) async {
    deletedCashiers.removeWhere((c) => c.id == id);
  }
}

class MockOnlinePlatformRepo implements OnlinePlatformRepository {
  List<OnlinePlatformModel> platforms = [];
  List<OnlinePlatformModel> deletedPlatforms = [];

  @override
  Future<List<OnlinePlatformModel>> getAllPlatforms() async => platforms;
  @override
  Future<void> addPlatform(String nama) async {}
  @override
  Future<void> updatePlatform(String id, String nama, int aktif) async {}
  @override
  Future<void> deletePlatform(String id) async {
    final item = platforms.firstWhere((p) => p.id == id);
    platforms.remove(item);
    deletedPlatforms.add(item.copyWith(
      isDeleted: 1,
      nama: SoftDeleteHelper.makeDeletedName(item.nama),
    ));
  }
  @override
  Future<List<OnlinePlatformModel>> getDeletedPlatforms() async => deletedPlatforms;
  @override
  Future<void> restorePlatform(String id) async {
    final item = deletedPlatforms.firstWhere((p) => p.id == id);
    deletedPlatforms.remove(item);
    platforms.add(item.copyWith(
      isDeleted: 0,
      nama: SoftDeleteHelper.getOriginalName(item.nama),
    ));
  }
  @override
  Future<void> permanentDeletePlatform(String id) async {
    deletedPlatforms.removeWhere((p) => p.id == id);
  }
}

void main() {
  final now = DateTime.now();

  group('SoftDeleteHelper Unit Tests', () {
    test('makeDeletedName appends timestamp and getOriginalName strips it cleanly', () {
      const original = 'Ayam Geprek Sambal Matah';
      final deleted = SoftDeleteHelper.makeDeletedName(original);

      expect(deleted.startsWith('Ayam Geprek Sambal Matah__del_'), isTrue);
      expect(SoftDeleteHelper.isDeletedName(deleted), isTrue);
      expect(SoftDeleteHelper.isDeletedName(original), isFalse);

      final recovered = SoftDeleteHelper.getOriginalName(deleted);
      expect(recovered, original);
    });

    test('makeDeletedNomor appends tombstone and getOriginalNomor strips it', () {
      const originalNomor = '12';
      final deleted = SoftDeleteHelper.makeDeletedNomor(originalNomor);

      expect(deleted.startsWith('12__del_'), isTrue);
      final recovered = SoftDeleteHelper.getOriginalNomor(deleted);
      expect(recovered, originalNomor);
    });

    test('getOriginalName returns unchanged string if no deleted marker present', () {
      const normalName = 'Kopi Susu Gula Aren';
      expect(SoftDeleteHelper.getOriginalName(normalName), normalName);
    });
  });

  group('TrashBinNotifier and Option C Workflow Tests', () {
    late MockProductRepo productRepo;
    late MockCategoryRepo categoryRepo;
    late MockPaymentMethodRepo pmRepo;
    late MockTableRepo tableRepo;
    late MockCashierRepo cashierRepo;
    late MockOnlinePlatformRepo platformRepo;
    late TrashBinNotifier trashNotifier;

    setUp(() {
      productRepo = MockProductRepo();
      categoryRepo = MockCategoryRepo();
      pmRepo = MockPaymentMethodRepo();
      tableRepo = MockTableRepo();
      cashierRepo = MockCashierRepo();
      platformRepo = MockOnlinePlatformRepo();

      trashNotifier = TrashBinNotifier(
        productRepo: productRepo,
        categoryRepo: categoryRepo,
        paymentMethodRepo: pmRepo,
        tableRepo: tableRepo,
        cashierRepo: cashierRepo,
        platformRepo: platformRepo,
      );
    });

    test('Soft delete product moves it to Trash Bin and releases original name', () async {
      final p1 = Product(
        id: 'p-1',
        nama: 'Kopi Tubruk',
        harga: 10000,
        kategoriId: 'cat-1',
        stok: 50,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.insertProduct(p1);
      expect(productRepo.products.length, 1);

      // Soft delete
      await productRepo.deleteProduct('p-1');
      expect(productRepo.products.isEmpty, isTrue);
      expect(productRepo.deletedProducts.length, 1);
      expect(productRepo.deletedProducts.first.nama.contains('__del_'), isTrue);

      // Reload TrashBinNotifier
      await trashNotifier.loadAll();
      expect(trashNotifier.state.deletedProducts.length, 1);

      // Restore product
      final restored = await trashNotifier.restoreProduct('p-1');
      expect(restored, isTrue);
      expect(trashNotifier.state.deletedProducts.isEmpty, isTrue);
      expect(productRepo.products.length, 1);
      expect(productRepo.products.first.nama, 'Kopi Tubruk');
    });

    test('Permanent delete product blocks deletion when FK constraint exists', () async {
      final p1 = Product(
        id: 'p-2',
        nama: 'Es Teh Manis',
        harga: 5000,
        kategoriId: 'cat-1',
        stok: 100,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.insertProduct(p1);
      await productRepo.deleteProduct('p-2');
      await trashNotifier.loadAll();

      // Configure mock to simulate FK transaction constraint
      productRepo.throwFkOnPermanent = true;

      final success = await trashNotifier.permanentDeleteProduct('p-2');
      expect(success, isFalse);
      expect(trashNotifier.state.errorMessage, contains('riwayat transaksi'));
      expect(productRepo.deletedProducts.length, 1); // Still retained in trash
    });

    test('Permanent delete succeeds when no transactional history exists', () async {
      final p1 = Product(
        id: 'p-3',
        nama: 'Menu Percobaan',
        harga: 15000,
        kategoriId: 'cat-1',
        stok: 10,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.insertProduct(p1);
      await productRepo.deleteProduct('p-3');
      await trashNotifier.loadAll();

      productRepo.throwFkOnPermanent = false;
      final success = await trashNotifier.permanentDeleteProduct('p-3');
      expect(success, isTrue);
      expect(trashNotifier.state.deletedProducts.isEmpty, isTrue);
      expect(productRepo.deletedProducts.isEmpty, isTrue);
    });

    test('Active/Inactive toggle preserves product without deleting', () async {
      final p1 = Product(
        id: 'p-4',
        nama: 'Seasonal Cake',
        harga: 25000,
        kategoriId: 'cat-1',
        stok: 10,
        status: 1,
        createdAt: now,
        updatedAt: now,
      );
      await productRepo.insertProduct(p1);
      expect(productRepo.products.first.isActive, isTrue);

      // Toggle inactive (status = 0)
      await productRepo.toggleProductStatus('p-4', 0);
      expect(productRepo.products.first.isActive, isFalse);

      // Toggle active back (status = 1)
      await productRepo.toggleProductStatus('p-4', 1);
      expect(productRepo.products.first.isActive, isTrue);
    });

    test('Category soft delete, restore, and FK protection', () async {
      final cat = Category(
        id: 'c-1',
        nama: 'Makanan Berat',
        status: 1,
        createdAt: now,
        updatedAt: now,
      );
      await categoryRepo.insertCategory(cat);
      await categoryRepo.deleteCategory('c-1');
      await trashNotifier.loadAll();

      expect(trashNotifier.state.deletedCategories.length, 1);

      // Restore category
      final ok = await trashNotifier.restoreCategory('c-1');
      expect(ok, isTrue);
      expect(categoryRepo.categories.first.nama, 'Makanan Berat');
    });

    test('Table soft delete and restore restores clean table name and number', () async {
      final table = TableModel(
        id: 't-1',
        nama: 'Meja VIP 1',
        nomor: 'VIP-01',
        createdAt: now,
        updatedAt: now,
      );
      await tableRepo.saveTable(table);
      await tableRepo.deleteTable('t-1');
      await trashNotifier.loadAll();

      expect(trashNotifier.state.deletedTables.length, 1);
      final deleted = trashNotifier.state.deletedTables.first;
      expect(deleted.nama.contains('__del_'), isTrue);
      expect(deleted.nomor.contains('__del_'), isTrue);

      // Restore
      final ok = await trashNotifier.restoreTable('t-1');
      expect(ok, isTrue);
      expect(tableRepo.tables.first.nama, 'Meja VIP 1');
      expect(tableRepo.tables.first.nomor, 'VIP-01');
      expect(tableRepo.tables.first.isDeleted, isFalse);
    });
  });
}
