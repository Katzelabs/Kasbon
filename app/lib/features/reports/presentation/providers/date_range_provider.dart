import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/get_profit_summary.dart';

/// Date range type for quick selection
enum DateRangeType {
  today,
  thisWeek,
  thisMonth,
  custom,
}

/// State class for date range selection
class DateRangeState {
  final DateRangeType type;
  final DateTime from;
  final DateTime to;

  const DateRangeState({
    required this.type,
    required this.from,
    required this.to,
  });

  /// Factory for today
  factory DateRangeState.today() {
    final params = DateRangeParams.today();
    return DateRangeState(
      type: DateRangeType.today,
      from: params.from,
      to: params.to,
    );
  }

  /// Factory for this week
  factory DateRangeState.thisWeek() {
    final params = DateRangeParams.thisWeek();
    return DateRangeState(
      type: DateRangeType.thisWeek,
      from: params.from,
      to: params.to,
    );
  }

  /// Factory for this month
  factory DateRangeState.thisMonth() {
    final params = DateRangeParams.thisMonth();
    return DateRangeState(
      type: DateRangeType.thisMonth,
      from: params.from,
      to: params.to,
    );
  }

  /// Factory for custom range
  factory DateRangeState.custom(DateTime from, DateTime to) {
    return DateRangeState(
      type: DateRangeType.custom,
      from: from,
      to: to,
    );
  }

  /// Convert to DateRangeParams
  DateRangeParams toParams() {
    return DateRangeParams(from: from, to: to);
  }

  /// Get display label for the date range
  String get label {
    return switch (type) {
      DateRangeType.today => 'Hari Ini',
      DateRangeType.thisWeek => 'Minggu Ini',
      DateRangeType.thisMonth => 'Bulan Ini',
      DateRangeType.custom => 'Kustom',
    };
  }
}

/// StateNotifier for managing date range selection
class DateRangeNotifier extends StateNotifier<DateRangeState> {
  DateRangeNotifier() : super(DateRangeState.thisMonth());

  /// Select today
  void selectToday() {
    state = DateRangeState.today();
  }

  /// Select this week
  void selectThisWeek() {
    state = DateRangeState.thisWeek();
  }

  /// Select this month
  void selectThisMonth() {
    state = DateRangeState.thisMonth();
  }

  /// Select custom date range
  void selectCustom(DateTime from, DateTime to) {
    state = DateRangeState.custom(from, to);
  }

  /// Select by type
  void selectByType(DateRangeType type) {
    switch (type) {
      case DateRangeType.today:
        selectToday();
        break;
      case DateRangeType.thisWeek:
        selectThisWeek();
        break;
      case DateRangeType.thisMonth:
        selectThisMonth();
        break;
      case DateRangeType.custom:
        // Keep current custom range or use default
        break;
    }
  }
}

/// Provider for date range selection
final dateRangeProvider =
    StateNotifierProvider<DateRangeNotifier, DateRangeState>((ref) {
  return DateRangeNotifier();
});
