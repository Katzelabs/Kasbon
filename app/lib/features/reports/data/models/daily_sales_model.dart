import '../../domain/entities/daily_sales.dart';

/// Data transfer object for DailySales
class DailySalesModel extends DailySales {
  const DailySalesModel({
    required super.date,
    required super.revenue,
    required super.transactionCount,
  });

  /// Create from database query result
  ///
  /// Expects the row to have:
  /// - 'sale_date': String in format 'YYYY-MM-DD'
  /// - 'revenue': num
  /// - 'transaction_count': num
  factory DailySalesModel.fromQueryResult(Map<String, dynamic> row) {
    final dateString = row['sale_date'] as String? ?? '';
    DateTime date;
    try {
      date = DateTime.parse(dateString);
    } catch (_) {
      date = DateTime.now();
    }

    return DailySalesModel(
      date: date,
      revenue: (row['revenue'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to entity
  DailySales toEntity() {
    return DailySales(
      date: date,
      revenue: revenue,
      transactionCount: transactionCount,
    );
  }
}
