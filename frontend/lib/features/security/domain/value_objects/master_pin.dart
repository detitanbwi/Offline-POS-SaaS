/// Value Object representing a Master PIN.
/// Ensures the PIN has at least 4-6 numeric digits.
class MasterPin {
  final String value;

  const MasterPin._(this.value);

  factory MasterPin(String value) {
    final trimmed = value.trim();
    if (!isValid(trimmed)) {
      throw ArgumentError('PIN Master harus berupa 4-6 digit angka: $value');
    }
    return MasterPin._(trimmed);
  }

  static bool isValid(String pin) {
    final regex = RegExp(r'^\d{4,6}$');
    return regex.hasMatch(pin.trim());
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterPin &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
