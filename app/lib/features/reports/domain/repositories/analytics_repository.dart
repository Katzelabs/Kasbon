import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/category_slice.dart';
import '../entities/customer_analytics.dart';
import '../entities/heatmap_cell.dart';
import '../entities/payment_slice.dart';
import '../entities/product_movement.dart';
import '../entities/report_filter.dart';
import '../entities/sales_trend_point.dart';

/// Abstract repository for the advanced analytics reports.
///
/// Kept separate from [ReportRepository] rather than extending it: these are
/// Pro-tier reports backed by their own RPCs, and the split keeps the free-tier
/// report surface unchanged.
abstract class AnalyticsRepository {
  /// Bucketed revenue and profit for the trend charts.
  ///
  /// Buckets with no sales are omitted; use [SalesTrendPointX.fillGaps] to
  /// produce a continuous series for charting.
  Future<Either<Failure, List<SalesTrendPoint>>> getSalesTrend({
    required DateTime from,
    required DateTime to,
    required TrendGranularity granularity,
    ReportFilter filter = ReportFilter.none,
  });

  /// Revenue, profit and units per category, for the distribution pie chart.
  ///
  /// Always line-item level - see [CategorySlice].
  Future<Either<Failure, List<CategorySlice>>> getCategoryDistribution({
    required DateTime from,
    required DateTime to,
    ReportFilter filter = ReportFilter.none,
  });

  /// Transaction count and total per payment method.
  ///
  /// Takes no filter: filtering the payment distribution by payment method
  /// would collapse the chart to a single slice.
  Future<Either<Failure, List<PaymentSlice>>> getPaymentDistribution({
    required DateTime from,
    required DateTime to,
  });

  /// Sparse 7x24 grid of sales by weekday and hour.
  ///
  /// Also backs the peak-hours and day-of-week analytics, which [HourlyHeatmap]
  /// derives from the same payload.
  Future<Either<Failure, HourlyHeatmap>> getHourlyHeatmap({
    required DateTime from,
    required DateTime to,
  });

  /// Highest-spending customers in the range, with all-time lifetime value.
  Future<Either<Failure, List<CustomerAnalytics>>> getTopCustomers({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  });

  /// Inventory movement for every active product.
  ///
  /// Backs both the turnover ranking and the slow-moving list; see
  /// [ProductMovementX]. [slowMovingDays] is the days-of-supply threshold above
  /// which a stocked product counts as slow-moving.
  Future<Either<Failure, List<ProductMovement>>> getProductMovement({
    required DateTime from,
    required DateTime to,
    int slowMovingDays = 90,
    int limit = 500,
  });
}
