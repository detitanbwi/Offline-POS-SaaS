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
  });
}
