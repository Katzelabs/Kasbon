import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/report_filter.dart';
import '../entities/sales_trend_point.dart';
import '../repositories/analytics_repository.dart';

/// Use case to get bucketed sales and profit data for the trend charts.
class GetSalesTrend extends UseCase<List<SalesTrendPoint>, SalesTrendParams> {
  final AnalyticsRepository repository;

  GetSalesTrend(this.repository);

  @override
  Future<Either<Failure, List<SalesTrendPoint>>> call(
      SalesTrendParams params) async {
    return await repository.getSalesTrend(
      from: params.from,
      to: params.to,
      granularity: params.granularity,
      filter: params.filter,
    );
  }
}

/// Parameters for the sales trend query.
class SalesTrendParams extends Equatable {
  final DateTime from;
  final DateTime to;
  final TrendGranularity granularity;
  final ReportFilter filter;

  const SalesTrendParams({
    required this.from,
    required this.to,
    this.granularity = TrendGranularity.day,
    this.filter = ReportFilter.none,
  });

  /// Pick a bucket size that keeps the chart readable for the given range.
  ///
  /// Daily points stay legible up to roughly two months; beyond that weekly
  /// buckets are used, and past a year monthly. Callers that expose an explicit
  /// granularity toggle should pass it instead of using this.
  factory SalesTrendParams.auto({
    required DateTime from,
    required DateTime to,
    ReportFilter filter = ReportFilter.none,
  }) {
    final days = to.difference(from).inDays;
    final granularity = days > 365
        ? TrendGranularity.month
        : days > 62
            ? TrendGranularity.week
            : TrendGranularity.day;
    return SalesTrendParams(
      from: from,
      to: to,
      granularity: granularity,
      filter: filter,
    );
  }

  @override
  List<Object?> get props => [from, to, granularity, filter];
}
