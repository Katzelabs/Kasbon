import '../../domain/entities/profit_summary.dart';

/// Data transfer object for ProfitSummary
class ProfitSummaryModel extends ProfitSummary {
  const ProfitSummaryModel({
    required super.totalProfit,
    required super.totalSales,
    required super.profitMargin,
    required super.transactionCount,
    required super.periodStart,
    required super.periodEnd,
  });

  /// Create from database query result
  factory ProfitSummaryModel.fromQueryResult({
    required Map<String, dynamic> row,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final totalSales = (row['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalProfit = (row['total_profit'] as num?)?.toDouble() ?? 0.0;
    final transactionCount = (row['transaction_count'] as num?)?.toInt() ?? 0;

    // Calculate profit margin
    final profitMargin = totalSales > 0 ? (totalProfit / totalSales) * 100 : 0.0;

    return ProfitSummaryModel(
      totalProfit: totalProfit,
      totalSales: totalSales,
      profitMargin: profitMargin,
      transactionCount: transactionCount,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  /// Convert to entity
  ProfitSummary toEntity() {
    return ProfitSummary(
      totalProfit: totalProfit,
      totalSales: totalSales,
      profitMargin: profitMargin,
      transactionCount: transactionCount,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
