import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/daily_sales.dart';
import '../entities/product_report.dart';
import '../entities/sales_summary.dart';

/// Sort type for product reports
enum ProductReportSortType {
  /// Sort by quantity sold (descending)
  quantity,

  /// Sort by total revenue (descending)
  revenue,

  /// Sort by total profit (descending)
  profit,
}

/// Abstract repository for basic reports
abstract class ReportRepository {
  /// Get sales summary for a date range
  ///
  /// Returns [SalesSummary] with total revenue, profit, transaction count, items sold
  Future<Either<Failure, SalesSummary>> getSalesSummary({
    required DateTime from,
    required DateTime to,
  });

  /// Get top selling products for a date range
  ///
  /// [sortBy] determines the sorting criteria (quantity, revenue, or profit)
  /// [limit] limits the number of products returned
  Future<Either<Failure, List<ProductReport>>> getTopProducts({
    required DateTime from,
    required DateTime to,
    required ProductReportSortType sortBy,
    required int limit,
  });

  /// Get daily sales data for chart visualization
  ///
  /// Returns a list of [DailySales] for each day in the date range
  Future<Either<Failure, List<DailySales>>> getDailySales({
    required DateTime from,
    required DateTime to,
  });
}
