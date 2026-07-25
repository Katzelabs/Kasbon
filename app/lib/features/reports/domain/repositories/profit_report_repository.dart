import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/product_profitability.dart';
import '../entities/profit_summary.dart';

/// Repository interface for profit reports
abstract class ProfitReportRepository {
  /// Get profit summary for a date range
  Future<Either<Failure, ProfitSummary>> getProfitByDateRange({
    required DateTime from,
    required DateTime to,
  });

  /// Get top profitable products
  Future<Either<Failure, List<ProductProfitability>>> getTopProfitableProducts({
    required int limit,
  });

  /// Get profitability for a specific product
  Future<Either<Failure, ProductProfitability>> getProductProfitability({
    required String productId,
  });
}
