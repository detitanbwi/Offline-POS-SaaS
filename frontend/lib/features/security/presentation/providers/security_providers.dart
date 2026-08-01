import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/security_database.dart';
import '../../data/repositories/security_repository_impl.dart';
import '../../domain/repositories/security_repository.dart';
import '../../services/security_service.dart';
import '../../../../core/di/providers.dart';

/// Provider for independent SecurityDatabase.
final securityDatabaseProvider = Provider<SecurityDatabase>((ref) {
  return SecurityDatabase.instance;
});

/// Provider for SecurityRepository interface.
final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  final db = ref.watch(securityDatabaseProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  return SecurityRepositoryImpl(db, storage);
});

/// Provider for SecurityService / Use Case logic.
final securityServiceProvider = Provider<SecurityService>((ref) {
  final repository = ref.watch(securityRepositoryProvider);
  return SecurityService(repository);
});
