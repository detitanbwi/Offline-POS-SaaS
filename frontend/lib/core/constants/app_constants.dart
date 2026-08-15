/// Application-wide constants, enums, and configuration values.
/// Centralizes magic strings and configuration to avoid duplication.
library;

/// API base URL for the SaaS backend server.
/// In production, this should be configured via environment or build config.
// const String apiBaseUrl = 'https://demo2.wirodev.com';
// const String apiBaseUrl = 'http://192.168.1.36:8000';
const String apiBaseUrl = 'https://demo2.rce-eastjava.org';

/// Application metadata
const String appVersion = '0.1.29';
const String appBuildNumber = '129';
const String appName = 'SaaS POS Offline';

/// Order Type constants
class AppOrderType {
  static const String dineIn = 'dine_in';
  static const String takeAway = 'take_away';
}

/// Order Status constants
class AppOrderStatus {
  static const String draft = 'draft';
  static const String processing = 'processing';
  static const String served = 'served';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  
  static const List<String> all = [draft, processing, served, completed, cancelled];
}

/// Payment Status constants
class AppPaymentStatus {
  static const String unpaid = 'unpaid';
  static const String billed = 'billed';
  static const String paid = 'paid';
  
  static const List<String> all = [unpaid, billed, paid];
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
