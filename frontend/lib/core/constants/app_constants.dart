/// Application-wide constants, enums, and configuration values.
/// Centralizes magic strings and configuration to avoid duplication.

/// API base URL for the SaaS backend server.
/// In production, this should be configured via environment or build config.
const String apiBaseUrl = 'https://demo2.wirodev.com';

/// Application metadata
const String appVersion = '1.0.0';
const String appBuildNumber = '1';
const String appName = 'SaaS POS Offline';

/// Order status constants
class OrderStatus {
  static const String draft = 'draft';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [draft, completed, cancelled];
}

/// Transaction status constants
class TransactionStatus {
  static const String completed = 'completed';
  static const String voided = 'voided';

  static const List<String> all = [completed, voided];
}

/// Printer type constants
class PrinterType {
  static const String cashier = 'cashier';
  static const String kitchen = 'kitchen';

  static const List<String> all = [cashier, kitchen];
}

/// Database version
const int posDatabaseVersion = 3;

/// License validation interval in days
const int licenseValidationIntervalDays = 7;

/// PIN minimum length
const int pinMinLength = 4;

/// PIN maximum length
const int pinMaxLength = 6;

/// API timeout in seconds
const int apiTimeoutSeconds = 10;
