import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/pos_database.dart';
import 'package:frontend/core/services/print_queue_service.dart';
import 'package:frontend/features/pos/domain/services/void_order_service.dart';
import 'package:frontend/features/security/domain/entities/security_credential.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';

class MockSecurityRepository implements SecurityRepository {
  final String validMasterPin;
  MockSecurityRepository(this.validMasterPin);

  @override
  Future<bool> validateMasterPin(String candidatePin) async {
    return candidatePin == validMasterPin;
  }

  @override
  Future<void> clearSecurityCredentials() async {}

  @override
  Future<SecurityCredential?> getSecurityCredential() async => null;

  @override
  Future<void> rotateMasterPinAndRecoveryCode({
    required String newMasterPinHash,
    required String newRecoveryCodeHash,
  }) async {}

  @override
  Future<void> saveSecurityCredential(SecurityCredential credential) async {}

  @override
  Future<void> updateMasterPinHash(String newMasterPinHash) async {}

  @override
  Future<bool> validateRecoveryCode(String candidateRecoveryCode) async => false;
}

class FakePrintQueueService extends Fake implements PrintQueueService {}

void main() {
  group('VoidOrderService Security Tests', () {
    const masterPin = '888999';
    const cashierPin = '123456';

    test('rejection: Cashier PIN is rejected with Exception before touching database', () async {
      final mockSecurity = MockSecurityRepository(masterPin);
      final fakePrintQueue = FakePrintQueueService();
      final voidService = VoidOrderService(PosDatabase.instance, fakePrintQueue, mockSecurity);

      expect(
        () async => await voidService.voidOrderItem(
          masterOrderId: 'mo-1',
          orderItemId: 'oi-1',
          qtyToVoid: 1,
          reason: 'Salah pesan',
          managerPin: cashierPin, // Cashier PIN
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('PIN Master/Owner tidak valid')),
        ),
      );
    });
  });
}
