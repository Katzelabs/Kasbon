import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dashboard_summary.dart';

/// Abstract repository interface for Dashboard operations
abstract class DashboardRepository {
  /// Get complete dashboard summary
  Future<Either<Failure, DashboardSummary>> getDashboardSummary();

  /// Get low stock product count only
  Future<Either<Failure, int>> getLowStockCount();
}
