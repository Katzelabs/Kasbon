import 'package:equatable/equatable.dart';

import 'sales_summary.dart';

/// Direction of a period-over-period change.
enum ChangeDirection { up, down, flat }

/// A single metric compared against the previous period.
class MetricChange extends Equatable {
  final double current;
  final double previous;

  const MetricChange({required this.current, required this.previous});

  /// Absolute change. Negative when the metric fell.
  double get delta => current - previous;

  /// Percentage change against the previous period.
  ///
  /// Null when the previous period was zero: growth from nothing is undefined
  /// rather than infinite, and the UI should show "baru" instead of a
  /// meaningless percentage.
  double? get percentChange {
    if (previous == 0) return null;
    return (delta / previous.abs()) * 100;
  }

  /// True when there is no previous baseline to compare against.
  bool get isNewActivity => previous == 0 && current > 0;

  ChangeDirection get direction {
    if (delta > 0) return ChangeDirection.up;
    if (delta < 0) return ChangeDirection.down;
    return ChangeDirection.flat;
  }

  bool get isImprovement => delta > 0;

  @override
  List<Object?> get props => [current, previous];
}

/// The selected period compared against the immediately preceding period of
/// equal length.
///
/// Built from two `get_sales_summary` calls rather than a dedicated RPC - the
/// range is already indexed, so a second call is cheaper than new SQL.
class PeriodComparison extends Equatable {
  /// Summary for the selected range.
  final SalesSummary current;

  /// Summary for the equal-length range immediately before it.
  final SalesSummary previous;

  const PeriodComparison({
    required this.current,
    required this.previous,
  });

  MetricChange get revenue => MetricChange(
        current: current.totalRevenue,
        previous: previous.totalRevenue,
      );

  MetricChange get profit => MetricChange(
        current: current.totalProfit,
        previous: previous.totalProfit,
      );

  MetricChange get transactionCount => MetricChange(
        current: current.transactionCount.toDouble(),
        previous: previous.transactionCount.toDouble(),
      );

  MetricChange get itemsSold => MetricChange(
        current: current.itemsSold.toDouble(),
        previous: previous.itemsSold.toDouble(),
      );

  MetricChange get averageTransactionValue => MetricChange(
        current: current.averageTransactionValue,
        previous: previous.averageTransactionValue,
      );

  MetricChange get profitMargin => MetricChange(
        current: current.profitMargin,
        previous: previous.profitMargin,
      );

  /// Whether the previous period had any activity to compare against.
  bool get hasBaseline =>
      previous.transactionCount > 0 || previous.totalRevenue != 0;

  /// Length of the compared period.
  Duration get periodLength =>
      current.periodEnd.difference(current.periodStart);

  @override
  List<Object?> get props => [current, previous];
}
