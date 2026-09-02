/// Application-wide constants, enums, and configuration values.
/// Centralizes magic strings and configuration to avoid duplication.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API base URL for the SaaS backend server.
/// Configured via .env files with fallback to production server.
String get apiBaseUrl => dotenv.env['API_BASE_URL']?.isNotEmpty == true
    ? dotenv.env['API_BASE_URL']!
    : 'https://aplikasi.appkasirpro.com';

/// Application metadata
const String appVersion = '1.0.3';
const String appBuildNumber = '3';
const String appName = 'Kasir Pro';

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

/// Standard HTTP Headers for all API requests to prevent bot false-positives (Imunify360/WAF)
Map<String, String> getApiHeaders({String? bearerToken}) {
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 SaaSPOS/$appVersion',
    if (bearerToken != null && bearerToken.isNotEmpty)
      'Authorization': 'Bearer $bearerToken',
  };
}
