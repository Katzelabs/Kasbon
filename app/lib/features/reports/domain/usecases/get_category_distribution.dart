import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/category_slice.dart';
import '../entities/report_filter.dart';
import '../repositories/analytics_repository.dart';

/// Use case to get the revenue breakdown by product category.
class GetCategoryDistribution
    extends UseCase<List<CategorySlice>, AnalyticsRangeParams> {
  final AnalyticsRepository repository;

  GetCategoryDistribution(this.repository);

  @override
  Future<Either<Failure, List<CategorySlice>>> call(
      AnalyticsRangeParams params) async {
    return await repository.getCategoryDistribution(
      from: params.from,
      to: params.to,
      filter: params.filter,
    );
  }
}

/// Parameters shared by the range-and-filter analytics queries.
class AnalyticsRangeParams extends Equatable {
  final DateTime from;
  final DateTime to;
  final ReportFilter filter;

  const AnalyticsRangeParams({
    required this.from,
    required this.to,
    this.filter = ReportFilter.none,
  });

  @override
  List<Object?> get props => [from, to, filter];
}
