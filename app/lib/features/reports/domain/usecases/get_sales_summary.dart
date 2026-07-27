import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/report_filter.dart';
import '../entities/sales_summary.dart';
import '../repositories/report_repository.dart';
import 'get_profit_summary.dart';

/// Use case to get sales summary for a date range
class GetSalesSummary extends UseCase<SalesSummary, SalesSummaryParams> {
  final ReportRepository repository;

  GetSalesSummary(this.repository);

  @override
  Future<Either<Failure, SalesSummary>> call(SalesSummaryParams params) async {
    return await repository.getSalesSummary(
      from: params.from,
      to: params.to,
      filter: params.filter,
    );
  }
}

/// Parameters for the sales summary query.
///
/// Separate from [DateRangeParams] because the profit reports share that class
/// and have no filter support; folding a filter into it would imply the profit
/// RPCs honour one when they do not.
class SalesSummaryParams extends Equatable {
  final DateTime from;
  final DateTime to;
  final ReportFilter filter;

  const SalesSummaryParams({
    required this.from,
    required this.to,
    this.filter = ReportFilter.none,
  });

  /// Build from a plain date range, for the unfiltered call sites.
  factory SalesSummaryParams.fromDateRange(
    DateRangeParams range, {
    ReportFilter filter = ReportFilter.none,
  }) {
    return SalesSummaryParams(
      from: range.from,
      to: range.to,
      filter: filter,
    );
  }

  @override
  List<Object?> get props => [from, to, filter];
}
