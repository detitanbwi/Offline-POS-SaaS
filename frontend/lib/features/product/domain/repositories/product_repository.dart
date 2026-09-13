import '../models/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  Future<Product?> getProductById(String id);
  Future<void> insertProduct(
    Product product, {
    DateTime? initialStockDate,
    String? initialStockNotes,
  });
  Future<void> updateProduct(Product product);
  Future<void> toggleProductStatus(String id, int status);
  Future<void> deleteProduct(String id);
  Future<List<Product>> getDeletedProducts();
  Future<void> restoreProduct(String id);
  Future<void> permanentDeleteProduct(String id);
  Future<bool> isProductNameExists(String name, {String? excludeId});
  Future<void> updateStock(String id, int quantityChange);
}
