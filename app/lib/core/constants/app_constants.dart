/// Application-wide constants for KASBON POS
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'KASBON';
  static const String appTagline = 'Kasir Digital untuk Semua';
  static const String appVersion = '1.0.0';

  // Business Defaults
  static const String defaultCurrency = 'IDR';
  static const String currencySymbol = 'Rp';
  static const String currencyLocale = 'id_ID';
  static const int defaultLowStockThreshold = 5;

  // Database
  static const String databaseName = 'kasbon.db';
  static const int databaseVersion = 1;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Transaction
  static const String transactionPrefix = 'TRX';
  static const String skuPrefix = 'SKU';

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
}
