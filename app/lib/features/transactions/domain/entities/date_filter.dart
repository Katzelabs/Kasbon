import 'package:flutter/material.dart';

/// Date filter options for transaction list filtering
enum DateFilter {
  today,
  yesterday,
  last7Days,
  last30Days,
  custom;

  /// Get display label in Bahasa Indonesia
  String get label {
    switch (this) {
      case DateFilter.today:
        return 'Hari Ini';
      case DateFilter.yesterday:
        return 'Kemarin';
      case DateFilter.last7Days:
        return '7 Hari';
      case DateFilter.last30Days:
        return '30 Hari';
      case DateFilter.custom:
        return 'Kustom';
    }
  }

  /// Get date range for this filter
  /// For custom filter, returns today as placeholder (actual range set separately)
  DateTimeRange get range {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (this) {
      case DateFilter.today:
        return DateTimeRange(start: startOfToday, end: endOfToday);
      case DateFilter.yesterday:
        final yesterday = startOfToday.subtract(const Duration(days: 1));
        final endOfYesterday = startOfToday.subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: yesterday, end: endOfYesterday);
      case DateFilter.last7Days:
        return DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 6)),
          end: endOfToday,
        );
      case DateFilter.last30Days:
        return DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 29)),
          end: endOfToday,
        );
      case DateFilter.custom:
        // For custom, return today as placeholder
        // Actual range should be set via customDateRangeProvider
        return DateTimeRange(start: startOfToday, end: endOfToday);
    }
  }
}
