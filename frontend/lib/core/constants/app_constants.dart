/// Application-wide constants, enums, and configuration values.
/// Centralizes magic strings and configuration to avoid duplication.
library;

/// API base URL for the SaaS backend server.
/// In production, this should be configured via environment or build config.
// const String apiBaseUrl = 'https://demo2.wirodev.com';
// const String apiBaseUrl = 'http://192.168.1.36:8000';
const String apiBaseUrl = 'https://demo2.rce-eastjava.org';

/// Application metadata
const String appVersion = '0.1.16';
const String appBuildNumber = '116';
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
const int posDatabaseVersion = 5;

/// License validation interval in days
const int licenseValidationIntervalDays = 7;

/// PIN minimum length
const int pinMinLength = 4;

/// PIN maximum length
const int pinMaxLength = 6;

/// API timeout in seconds
const int apiTimeoutSeconds = 10;
