import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Utility class for formatting currency values
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 0,
  );

  static final NumberFormat _formatterWithDecimal = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  /// Format a number as Indonesian Rupiah
  /// Example: 10000 -> "Rp10.000"
  static String format(num value) {
    return _formatter.format(value);
  }

  /// Format a number as Indonesian Rupiah with decimal places
  /// Example: 10000.50 -> "Rp10.000,50"
  static String formatWithDecimal(num value) {
    return _formatterWithDecimal.format(value);
  }

  /// Format a number as compact currency
  /// Example: 1000000 -> "Rp1jt"
  static String formatCompact(num value) {
    if (value >= 1000000000) {
      return '${AppConstants.currencySymbol}${(value / 1000000000).toStringAsFixed(1)}M';
    } else if (value >= 1000000) {
      return '${AppConstants.currencySymbol}${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return '${AppConstants.currencySymbol}${(value / 1000).toStringAsFixed(1)}rb';
    }
    return format(value);
  }

  /// Parse a formatted currency string back to a number
  /// Example: "Rp10.000" -> 10000
  static num? parse(String value) {
    try {
      final cleaned = value
          .replaceAll(AppConstants.currencySymbol, '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      return num.parse(cleaned);
    } catch (_) {
      return null;
    }
  }
}
