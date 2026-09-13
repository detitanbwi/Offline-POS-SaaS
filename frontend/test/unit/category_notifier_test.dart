import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/category/domain/repositories/category_repository.dart';
import 'package:frontend/features/category/domain/models/category.dart';
import 'package:frontend/features/category/application/category_notifier.dart';

class CategoryRepositoryMock implements CategoryRepository {
  final List<Category> categories = [];

  @override
  Future<List<Category>> getAllCategories() async {
    return categories;
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insertCategory(Category category) async {
    categories.add(category);
  }

  @override
  Future<void> updateCategory(Category category) async {
    final idx = categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      categories[idx] = category;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    categories.removeWhere((c) => c.id == id);
  }

  @override
  Future<bool> isCategoryNameExists(String name, {String? excludeId}) async {
    return categories.any((c) => c.nama.toLowerCase() == name.toLowerCase() && c.id != excludeId);
  }
}

void main() {
  group('CategoryNotifier Bulk Addition Tests', () {
    late CategoryRepositoryMock mockRepository;
    late CategoryNotifier notifier;

    setUp(() {
      mockRepository = CategoryRepositoryMock();
      notifier = CategoryNotifier(mockRepository);
    });

    test('addCategories adds multiple unique categories successfully', () async {
      final success = await notifier.addCategories(['Makanan', 'Minuman', 'Dessert']);
      expect(success, true);
      expect(notifier.state.allCategories.length, 3);
      expect(notifier.state.allCategories.any((c) => c.nama == 'Makanan'), true);
      expect(notifier.state.allCategories.any((c) => c.nama == 'Minuman'), true);
      expect(notifier.state.allCategories.any((c) => c.nama == 'Dessert'), true);
    });

    test('addCategories filters out duplicates and saves the rest', () async {
      // Pre-add Makanan
      await mockRepository.insertCategory(Category(
        id: '1',
        nama: 'Makanan',
        status: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await notifier.loadCategories();

      final success = await notifier.addCategories(['Makanan', 'Cemilan']);
      expect(success, true); // True because 'Cemilan' is added
      expect(notifier.state.allCategories.length, 2);
      expect(notifier.state.allCategories.any((c) => c.nama == 'Makanan'), true);
      expect(notifier.state.allCategories.any((c) => c.nama == 'Cemilan'), true);
    });

    test('addCategory sequentially adds Makanan and then Minuman, displaying both in filteredCategories', () async {
      // 1. Add first category "Makanan"
      final success1 = await notifier.addCategory('Makanan');
      expect(success1, true);
      expect(notifier.state.allCategories.length, 1);
      expect(notifier.state.filteredCategories.length, 1);
      expect(notifier.state.filteredCategories.first.nama, 'Makanan');

      // 2. Add second category "Minuman"
      final success2 = await notifier.addCategory('Minuman');
      expect(success2, true);
      expect(notifier.state.allCategories.length, 2);
      expect(notifier.state.filteredCategories.length, 2);
      expect(notifier.state.filteredCategories.any((c) => c.nama == 'Makanan'), true);
      expect(notifier.state.filteredCategories.any((c) => c.nama == 'Minuman'), true);
    });

    test('addCategory resets search query so newly added category is visible', () async {
      await notifier.addCategory('Makanan');
      notifier.setSearchQuery('makanan');
      expect(notifier.state.filteredCategories.length, 1);

      // Adding Minuman resets the search query
      final success = await notifier.addCategory('Minuman');
      expect(success, true);
      expect(notifier.state.searchQuery, '');
      expect(notifier.state.filteredCategories.length, 2);
      expect(notifier.state.filteredCategories.any((c) => c.nama == 'Minuman'), true);
    });
  });
}
