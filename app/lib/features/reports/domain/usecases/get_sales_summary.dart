import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/sales_summary.dart';
import '../repositories/report_repository.dart';
import 'get_profit_summary.dart';

/// Use case to get sales summary for a date range
class GetSalesSummary extends UseCase<SalesSummary, DateRangeParams> {
  final ReportRepository repository;

  GetSalesSummary(this.repository);

  @override
  Future<Either<Failure, SalesSummary>> call(DateRangeParams params) async {
    return await repository.getSalesSummary(
      from: params.from,
      to: params.to,
    );
  }
}
