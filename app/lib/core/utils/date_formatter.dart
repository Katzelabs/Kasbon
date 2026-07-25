import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Utility class for formatting date and time values
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormatter =
      DateFormat(AppConstants.dateFormat, 'id_ID');
  static final DateFormat _timeFormatter =
      DateFormat(AppConstants.timeFormat, 'id_ID');
  static final DateFormat _dateTimeFormatter =
      DateFormat(AppConstants.dateTimeFormat, 'id_ID');
  static final DateFormat _monthYearFormatter =
      DateFormat('MMMM yyyy', 'id_ID');
  static final DateFormat _dayMonthFormatter = DateFormat('d MMMM', 'id_ID');

  /// Format date as dd/MM/yyyy
  static String formatDate(DateTime date) {
    return _dateFormatter.format(date);
  }

  /// Format time as HH:mm
  static String formatTime(DateTime date) {
    return _timeFormatter.format(date);
  }

  /// Format date and time as dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime date) {
    return _dateTimeFormatter.format(date);
  }

  /// Format as month and year (e.g., "Januari 2024")
  static String formatMonthYear(DateTime date) {
    return _monthYearFormatter.format(date);
  }

  /// Format as day and month (e.g., "15 Januari")
  static String formatDayMonth(DateTime date) {
    return _dayMonthFormatter.format(date);
  }

  /// Get relative time string (e.g., "Hari ini", "Kemarin", "3 hari lalu")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) {
      return 'Hari ini';
    } else if (difference == 1) {
      return 'Kemarin';
    } else if (difference < 7) {
      return '$difference hari lalu';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '$weeks minggu lalu';
    } else {
      return formatDate(date);
    }
  }

  /// Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Get start of week (Monday)
  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return startOfDay(date.subtract(Duration(days: weekday - 1)));
  }

  /// Get start of month
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }
}
