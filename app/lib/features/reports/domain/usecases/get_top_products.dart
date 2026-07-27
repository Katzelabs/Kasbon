import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/business_time.dart';
import '../entities/product_report.dart';
import '../entities/report_filter.dart';
import '../repositories/report_repository.dart';

/// Use case to get top selling products for a date range
class GetTopProducts extends UseCase<List<ProductReport>, TopProductsParams> {
  final ReportRepository repository;

  GetTopProducts(this.repository);

  @override
  Future<Either<Failure, List<ProductReport>>> call(
      TopProductsParams params) async {
    return await repository.getTopProducts(
      from: params.from,
      to: params.to,
      sortBy: params.sortBy,
      limit: params.limit,
      filter: params.filter,
    );
  }
}

/// Parameters for top products query
class TopProductsParams extends Equatable {
  final DateTime from;
  final DateTime to;
  final ProductReportSortType sortBy;
  final int limit;

  /// Optional category and/or payment method narrowing.
  final ReportFilter filter;

  const TopProductsParams({
    required this.from,
    required this.to,
    required this.sortBy,
    this.limit = 10,
    this.filter = ReportFilter.none,
  });

  /// Factory for today with default sort by quantity
  factory TopProductsParams.today({
    ProductReportSortType sortBy = ProductReportSortType.quantity,
    int limit = 10,
  }) {
    final startOfDay = BusinessTime.startOfDay();
    return TopProductsParams(
      from: startOfDay,
      to: DateTime(startOfDay.year, startOfDay.month, startOfDay.day + 1),
      sortBy: sortBy,
      limit: limit,
    );
  }

  /// Factory for this week with default sort by quantity
  factory TopProductsParams.thisWeek({
    ProductReportSortType sortBy = ProductReportSortType.quantity,
    int limit = 10,
  }) {
    final startOfWeek = BusinessTime.startOfWeek();
    return TopProductsParams(
      from: startOfWeek,
      to: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 7),
      sortBy: sortBy,
      limit: limit,
    );
  }

  /// Factory for this month with default sort by quantity
  factory TopProductsParams.thisMonth({
    ProductReportSortType sortBy = ProductReportSortType.quantity,
    int limit = 10,
  }) {
    final startOfMonth = BusinessTime.startOfMonth();
    return TopProductsParams(
      from: startOfMonth,
      to: DateTime(startOfMonth.year, startOfMonth.month + 1),
      sortBy: sortBy,
      limit: limit,
    );
  }

  @override
  List<Object?> get props => [from, to, sortBy, limit, filter];
}
