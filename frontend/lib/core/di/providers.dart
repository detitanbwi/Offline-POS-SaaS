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
import '../../features/table/domain/repositories/table_repository.dart';
import '../../features/table/data/repositories/table_repository_impl.dart';
import '../../features/printer/domain/repositories/printer_repository.dart';
import '../../features/printer/data/repositories/printer_repository_impl.dart';
import '../../features/pos/domain/repositories/order_repository.dart';
import '../../features/pos/data/repositories/order_repository_impl.dart';
import '../../features/auth/services/secure_storage_service.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/license/services/license_service.dart';
import '../../features/settings/services/backup_service.dart';
import '../services/device_fingerprint_service.dart';
import '../../features/cashier/domain/repositories/cashier_repository.dart';
import '../../features/cashier/data/repositories/cashier_repository_impl.dart';
import '../../features/pos/domain/repositories/online_platform_repository.dart';
import '../../features/pos/data/repositories/online_platform_repository_impl.dart';
import '../services/print_queue_service.dart';
import '../../features/table/domain/models/table_ui_state.dart';
import '../../features/table/data/repositories/reactive_table_repository.dart';
import '../../features/pos/domain/services/table_transfer_service.dart';
import '../../features/pos/domain/services/split_payment_service.dart';
import '../../features/pos/domain/services/void_order_service.dart';
import '../../features/pos/domain/services/online_food_order_service.dart';


// Database Provider
final posDatabaseProvider = Provider<PosDatabase>((ref) {
  return PosDatabase.instance;
});

// Services Providers
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final deviceFingerprintServiceProvider = Provider<DeviceFingerprintService>((ref) {
  return DeviceFingerprintService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthService(storage);
});

final licenseServiceProvider = Provider<LicenseService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final fingerprint = ref.watch(deviceFingerprintServiceProvider);
  return LicenseService(storage, fingerprint);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
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

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return TableRepositoryImpl(db);
});

final printerRepositoryProvider = Provider<PrinterRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return PrinterRepositoryImpl(db);
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return OrderRepositoryImpl(db);
});

final cashierRepositoryProvider = Provider<CashierRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return CashierRepositoryImpl(db);
});

final onlinePlatformRepositoryProvider = Provider<OnlinePlatformRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return OnlinePlatformRepositoryImpl(db);
});

// New POS Domain & Reactive Table Providers
final printQueueServiceProvider = Provider<PrintQueueService>((ref) {
  final db = ref.watch(posDatabaseProvider);
  final service = PrintQueueService(db);
  service.startBackgroundWorker();
  ref.onDispose(() => service.stopBackgroundWorker());
  return service;
});

final reactiveTableRepositoryProvider = Provider<ReactiveTableRepository>((ref) {
  final db = ref.watch(posDatabaseProvider);
  final repo = ReactiveTableRepository(db);
  ref.onDispose(() => repo.dispose());
  return repo;
});

final tableUiStateStreamProvider = StreamProvider<List<TableUiModel>>((ref) {
  final repo = ref.watch(reactiveTableRepositoryProvider);
  repo.loadAndEmitTables();
  return repo.tableUiStateStream;
});

final tableTransferServiceProvider = Provider<TableTransferService>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return TableTransferService(db);
});

final splitPaymentServiceProvider = Provider<SplitPaymentService>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return SplitPaymentService(db);
});

final voidOrderServiceProvider = Provider<VoidOrderService>((ref) {
  final db = ref.watch(posDatabaseProvider);
  final printQueue = ref.watch(printQueueServiceProvider);
  return VoidOrderService(db, printQueue);
});

final onlineFoodOrderServiceProvider = Provider<OnlineFoodOrderService>((ref) {
  final db = ref.watch(posDatabaseProvider);
  return OnlineFoodOrderService(db);
});
