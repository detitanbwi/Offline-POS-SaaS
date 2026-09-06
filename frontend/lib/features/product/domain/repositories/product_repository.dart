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
  Future<void> deleteProduct(String id);
  Future<bool> isProductNameExists(String name, {String? excludeId});
  Future<void> updateStock(String id, int quantityChange);
}
