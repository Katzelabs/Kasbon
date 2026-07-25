import 'package:equatable/equatable.dart';

/// Profit summary entity for a date range
class ProfitSummary extends Equatable {
  /// Total profit in the period
  final double totalProfit;

  /// Total sales in the period
  final double totalSales;

  /// Profit margin percentage
  final double profitMargin;

  /// Number of transactions in the period
  final int transactionCount;

  /// Start of the period
  final DateTime periodStart;

  /// End of the period
  final DateTime periodEnd;

  const ProfitSummary({
    required this.totalProfit,
    required this.totalSales,
    required this.profitMargin,
    required this.transactionCount,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Calculate profit margin if not provided
  double get calculatedProfitMargin {
    if (totalSales == 0) return 0;
    return (totalProfit / totalSales) * 100;
  }

  /// Empty state
  static ProfitSummary empty(DateTime start, DateTime end) => ProfitSummary(
        totalProfit: 0,
        totalSales: 0,
        profitMargin: 0,
        transactionCount: 0,
        periodStart: start,
        periodEnd: end,
      );

  @override
  List<Object?> get props => [
        totalProfit,
        totalSales,
        profitMargin,
        transactionCount,
        periodStart,
        periodEnd,
      ];
}
