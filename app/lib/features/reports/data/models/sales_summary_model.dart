import '../../domain/entities/sales_summary.dart';

/// Data transfer object for SalesSummary
class SalesSummaryModel extends SalesSummary {
  const SalesSummaryModel({
    required super.totalRevenue,
    required super.totalProfit,
    required super.transactionCount,
    required super.itemsSold,
    required super.periodStart,
    required super.periodEnd,
  });

  /// Create from database query results
  ///
  /// Expects two query result maps:
  /// - transactionResult: with 'total_revenue' and 'transaction_count'
  /// - itemsResult: with 'total_profit' and 'items_sold'
  factory SalesSummaryModel.fromQueryResults({
    required Map<String, dynamic> transactionResult,
    required Map<String, dynamic> itemsResult,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final totalRevenue =
        (transactionResult['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final transactionCount =
        (transactionResult['transaction_count'] as num?)?.toInt() ?? 0;
    final totalProfit =
        (itemsResult['total_profit'] as num?)?.toDouble() ?? 0.0;
    final itemsSold = (itemsResult['items_sold'] as num?)?.toInt() ?? 0;

    return SalesSummaryModel(
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      transactionCount: transactionCount,
      itemsSold: itemsSold,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  /// Convert to entity
  SalesSummary toEntity() {
    return SalesSummary(
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      transactionCount: transactionCount,
      itemsSold: itemsSold,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
