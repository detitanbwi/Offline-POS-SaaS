import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/security/domain/entities/security_credential.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/security/services/security_service.dart';

class FakeSecurityRepository implements SecurityRepository {
  SecurityCredential? _credential;
  String? _localPin;

  @override
  Future<void> saveSecurityCredential(SecurityCredential credential) async {
    _credential = credential;
    _localPin = credential.masterPinHash;
  }

  @override
  Future<SecurityCredential?> getSecurityCredential() async {
    return _credential;
  }

  @override
  Future<bool> validateRecoveryCode(String candidateRecoveryCode) async {
    return false;
  }

  @override
  Future<bool> validateMasterPin(String candidatePin) async {
    if (_credential == null) return false;
    // For test verification we use raw hash comparison from service
    final service = SecurityService(this);
    final candidateHash = await service.hashSecret(candidatePin);
    return _credential!.masterPinHash == candidateHash ||
           _credential!.masterPinHash == candidatePin ||
           _localPin == candidateHash;
  }

  @override
  Future<void> rotateMasterPinAndRecoveryCode({
    required String newMasterPinHash,
    required String newRecoveryCodeHash,
  }) async {
    final now = DateTime.now();
    _credential = _credential?.copyWith(
          masterPinHash: newMasterPinHash,
          recoveryCodeHash: newRecoveryCodeHash,
          updatedAt: now,
        ) ??
        SecurityCredential(
          id: 'master_security_core',
          masterPinHash: newMasterPinHash,
          recoveryCodeHash: newRecoveryCodeHash,
          licenseKeyLastSix: '123456',
          createdAt: now,
          updatedAt: now,
        );
    _localPin = newMasterPinHash;
  }

  @override
  Future<void> updateMasterPinHash(String newMasterPinHash) async {
    final now = DateTime.now();
    if (_credential != null) {
      _credential = _credential!.copyWith(
        masterPinHash: newMasterPinHash,
        updatedAt: now,
      );
    } else {
      _credential = SecurityCredential(
        id: 'master_security_core',
        masterPinHash: newMasterPinHash,
        recoveryCodeHash: '',
        licenseKeyLastSix: '123456',
        createdAt: now,
        updatedAt: now,
      );
    }
    _localPin = newMasterPinHash;
  }

  @override
  Future<void> clearSecurityCredentials() async {
    _credential = null;
    _localPin = null;
  }
}

void main() {
  group('SecurityService - changeMasterPin Tests', () {
    late FakeSecurityRepository repository;
    late SecurityService service;

    setUp(() {
      repository = FakeSecurityRepository();
      service = SecurityService(repository);
    });

    test('should fail to change Master PIN if old PIN is invalid', () async {
      await service.initializeMasterSecurity(
        masterPin: '123456',
        licenseKey: 'XXXX-XXXX-123456',
      );

      final success = await service.changeMasterPin(
        oldMasterPin: '000000', // incorrect old PIN
        newMasterPin: '654321',
      );

      expect(success, false);
    });

    test('should successfully change Master PIN when old PIN is correct', () async {
      await service.initializeMasterSecurity(
        masterPin: '123456',
        licenseKey: 'XXXX-XXXX-123456',
      );

      final success = await service.changeMasterPin(
        oldMasterPin: '123456', // correct old PIN
        newMasterPin: '654321', // new PIN
      );

      expect(success, true);

      // Verify old PIN no longer validates
      final isOldValid = await repository.validateMasterPin('123456');
      expect(isOldValid, false);

      // Verify new PIN now validates
      final isNewValid = await repository.validateMasterPin('654321');
      expect(isNewValid, true);
    });
  });
}
