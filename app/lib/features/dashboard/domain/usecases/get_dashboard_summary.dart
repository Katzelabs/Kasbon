import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// Use case to get complete dashboard summary
class GetDashboardSummary extends UseCaseNoParams<DashboardSummary> {
  final DashboardRepository repository;

  GetDashboardSummary(this.repository);

  @override
  Future<Either<Failure, DashboardSummary>> call() async {
    return await repository.getDashboardSummary();
  }
}
