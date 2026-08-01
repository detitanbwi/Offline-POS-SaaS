import 'dart:math';

/// Value Object representing a 12-character alphanumeric Recovery Code.
/// Example format: R-9X2P-L44M-Q1 (14 chars with hyphens, 12 alphanumeric characters).
class RecoveryCode {
  final String value;

  const RecoveryCode._(this.value);

  /// Factory constructor that validates the code format.
  factory RecoveryCode(String value) {
    final normalized = normalize(value);
    if (!isValidFormat(normalized)) {
      throw ArgumentError('Format Kode Pemulihan tidak valid: $value');
    }
    return RecoveryCode._(format(normalized));
  }

  /// Generates a cryptographically secure 12-character alphanumeric recovery code.
  /// Format: R-XXXX-XXXX-XX (e.g., R-9X2P-L44M-Q1).
  static RecoveryCode generate() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Avoid confusing chars like 0, O, 1, I
    final random = Random.secure();
    
    // We need 11 random characters after the prefix 'R' (total 12 alphanumeric chars: R + 4 + 4 + 2 + 1 = 12)
    // Format: R-XXXX-XXXX-XX => R (1) + 4 + 4 + 3 = 12 characters
    String genGroup(int length) {
      return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
    }

    // Example: R-9X2P-L44M-Q1 -> R (1 char) - 9X2P (4 chars) - L44M (4 chars) - Q1 (2 chars) -> wait, R + 4 + 4 + 2 = 11 chars. Let's add 1 more character to Q12 so it is exactly 12 alphanumeric characters!
    // Or let's use R-XXXX-XXXX-XXX (1 + 4 + 4 + 3 = 12 alphanumeric characters).
    final group1 = genGroup(4);
    final group2 = genGroup(4);
    final group3 = genGroup(3); // R + 4 + 4 + 3 = 12 alphanumeric chars

    final formatted = 'R-$group1-$group2-$group3';
    return RecoveryCode._(formatted);
  }

  /// Removes hyphens, spaces, and converts to uppercase.
  static String normalize(String raw) {
    return raw.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
  }

  /// Formats a normalized 12-character string into R-XXXX-XXXX-XXX.
  static String format(String normalized) {
    if (normalized.length != 12) return normalized;
    if (!normalized.startsWith('R')) return normalized;
    final g1 = normalized.substring(1, 5);
    final g2 = normalized.substring(5, 9);
    final g3 = normalized.substring(9, 12);
    return 'R-$g1-$g2-$g3';
  }

  /// Validates whether the normalized code has 12 alphanumeric characters starting with 'R'.
  static bool isValidFormat(String normalizedCode) {
    final normalized = normalize(normalizedCode);
    if (normalized.length != 12) return false;
    if (!normalized.startsWith('R')) return false;
    final regex = RegExp(r'^[A-Z0-9]{12}$');
    return regex.hasMatch(normalized);
  }

  /// Returns the raw normalized code without hyphens.
  String get normalized => normalize(value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryCode &&
          runtimeType == other.runtimeType &&
          normalized == other.normalized;

  @override
  int get hashCode => normalized.hashCode;
}
