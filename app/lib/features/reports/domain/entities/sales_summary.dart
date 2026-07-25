import 'package:equatable/equatable.dart';

/// Sales summary entity for a date range
class SalesSummary extends Equatable {
  /// Total revenue (sum of all transaction totals)
  final double totalRevenue;

  /// Total profit (selling price - cost price * quantity)
  final double totalProfit;

  /// Number of transactions in the period
  final int transactionCount;

  /// Total items sold
  final int itemsSold;

  /// Start of the period
  final DateTime periodStart;

  /// End of the period
  final DateTime periodEnd;

  const SalesSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.transactionCount,
    required this.itemsSold,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Calculated profit margin percentage
  double get profitMargin {
    if (totalRevenue == 0) return 0;
    return (totalProfit / totalRevenue) * 100;
  }

  /// Average transaction value
  double get averageTransactionValue {
    if (transactionCount == 0) return 0;
    return totalRevenue / transactionCount;
  }

  /// Empty state factory
  static SalesSummary empty(DateTime start, DateTime end) => SalesSummary(
        totalRevenue: 0,
        totalProfit: 0,
        transactionCount: 0,
        itemsSold: 0,
        periodStart: start,
        periodEnd: end,
      );

  @override
  List<Object?> get props => [
        totalRevenue,
        totalProfit,
        transactionCount,
        itemsSold,
        periodStart,
        periodEnd,
      ];
}
