import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/daily_sales.dart';
import '../repositories/report_repository.dart';
import 'get_profit_summary.dart';

/// Use case to get daily sales data for chart visualization
class GetDailySales extends UseCase<List<DailySales>, DateRangeParams> {
  final ReportRepository repository;

  GetDailySales(this.repository);

  @override
  Future<Either<Failure, List<DailySales>>> call(DateRangeParams params) async {
    return await repository.getDailySales(
      from: params.from,
      to: params.to,
    );
  }
}
