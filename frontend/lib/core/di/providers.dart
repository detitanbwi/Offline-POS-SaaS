import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/pos_database.dart';
import '../../features/category/domain/repositories/category_repository.dart';
import '../../features/category/data/repositories/category_repository_impl.dart';
import '../../features/product/domain/repositories/product_repository.dart';
import '../../features/product/data/repositories/product_repository_impl.dart';
import '../../features/stock/domain/repositories/stock_repository.dart';
import '../../features/stock/data/repositories/stock_repository_impl.dart';
import '../../features/payment_method/domain/repositories/payment_method_repository.dart';
import '../../features/payment_method/data/repositories/payment_method_repository_impl.dart';
import '../../features/tax/domain/repositories/tax_repository.dart';
import '../../features/tax/data/repositories/tax_repository_impl.dart';
import '../../features/pos/domain/repositories/transaction_repository.dart';
import '../../features/pos/data/repositories/transaction_repository_impl.dart';

// Database Provider
final posDatabaseProvider = Provider<PosDatabase>((ref) {
  return PosDatabase.instance;
});

// Repositories Providers
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return CategoryRepositoryImpl(db);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return ProductRepositoryImpl(db);
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return StockRepositoryImpl(db);
});

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return PaymentMethodRepositoryImpl(db);
});

final taxRepositoryProvider = Provider<TaxRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return TaxRepositoryImpl(db);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return TransactionRepositoryImpl(db);
});
