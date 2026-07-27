import '../../domain/entities/report_filter.dart';
import '../../domain/entities/sales_trend_point.dart';
import 'report_json.dart';

/// Data transfer object for [SalesTrendPoint].
class SalesTrendPointModel extends SalesTrendPoint {
  const SalesTrendPointModel({
    required super.bucketStart,
    required super.granularity,
    required super.revenue,
    required super.profit,
    required super.transactionCount,
    required super.itemsSold,
    super.revenueBasis,
  });

  /// Create from a `get_sales_trend` row.
  ///
  /// Expects:
  /// - 'bucket_start': String 'YYYY-MM-DD' (already in shop-local time)
  /// - 'granularity': 'day' | 'week' | 'month'
  /// - 'revenue', 'profit': num
  /// - 'transaction_count', 'items_sold': num
  /// - 'revenue_basis': 'transaction' | 'items'
  factory SalesTrendPointModel.fromQueryResult(Map<String, dynamic> row) {
    return SalesTrendPointModel(
      bucketStart: asLocalDateOrNull(row['bucket_start']) ?? DateTime.now(),
      granularity:
          TrendGranularity.fromWire(asStringOrNull(row['granularity'])),
      revenue: asDouble(row['revenue']),
      profit: asDouble(row['profit']),
      transactionCount: asInt(row['transaction_count']),
      itemsSold: asInt(row['items_sold']),
      revenueBasis: RevenueBasis.fromWire(asStringOrNull(row['revenue_basis'])),
    );
  }

  /// Convert to entity.
  SalesTrendPoint toEntity() {
    return SalesTrendPoint(
      bucketStart: bucketStart,
      granularity: granularity,
      revenue: revenue,
      profit: profit,
      transactionCount: transactionCount,
      itemsSold: itemsSold,
      revenueBasis: revenueBasis,
    );
  }
}
