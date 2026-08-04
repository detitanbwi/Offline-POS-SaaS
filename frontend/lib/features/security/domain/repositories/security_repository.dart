import '../entities/security_credential.dart';

/// Repository interface for the independent Core Domain: License & Security.
/// Isolates security credential storage from product/transaction database operations.
abstract class SecurityRepository {
  /// Saves the initial or updated security credential (Master PIN & Recovery Code hashes).
  Future<void> saveSecurityCredential(SecurityCredential credential);

  /// Retrieves the currently stored security credential, or null if none exists.
  Future<SecurityCredential?> getSecurityCredential();

  /// Validates a candidate recovery code against the stored hash.
  Future<bool> validateRecoveryCode(String candidateRecoveryCode);

  /// Validates a candidate Master PIN against the stored hash.
  Future<bool> validateMasterPin(String candidatePin);

  /// Rotates the Master PIN and Recovery Code after self-recovery,
  /// burning/deleting the old recovery code hash.
  Future<void> rotateMasterPinAndRecoveryCode({
    required String newMasterPinHash,
    required String newRecoveryCodeHash,
  });

  /// Updates only the Master PIN hash without rotating the Recovery Code.
  Future<void> updateMasterPinHash(String newMasterPinHash);

  /// Clears stored credentials.
  Future<void> clearSecurityCredentials();
}

