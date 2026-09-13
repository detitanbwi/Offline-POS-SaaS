import '../models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getAllCategories();
  Future<Category?> getCategoryById(String id);
  Future<void> insertCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> toggleCategoryStatus(String id, int status);
  Future<void> deleteCategory(String id);
  Future<List<Category>> getDeletedCategories();
  Future<void> restoreCategory(String id);
  Future<void> permanentDeleteCategory(String id);
  Future<bool> isCategoryNameExists(String name, {String? excludeId});
}
