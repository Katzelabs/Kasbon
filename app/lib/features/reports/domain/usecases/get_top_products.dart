import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product_report.dart';
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
    );
  }
}

/// Parameters for top products query
class TopProductsParams extends Equatable {
  final DateTime from;
  final DateTime to;
  final ProductReportSortType sortBy;
  final int limit;

  const TopProductsParams({
    required this.from,
    required this.to,
    required this.sortBy,
    this.limit = 10,
  });

  /// Factory for today with default sort by quantity
  factory TopProductsParams.today({
    ProductReportSortType sortBy = ProductReportSortType.quantity,
    int limit = 10,
  }) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return TopProductsParams(
      from: startOfDay,
      to: endOfDay,
      sortBy: sortBy,
      limit: limit,
    );
  }

  /// Factory for this week with default sort by quantity
  factory TopProductsParams.thisWeek({
    ProductReportSortType sortBy = ProductReportSortType.quantity,
    int limit = 10,
  }) {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final startOfWeek =
        DateTime(now.year, now.month, now.day - dayOfWeek + 1);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return TopProductsParams(
      from: startOfWeek,
      to: endOfWeek,
      sortBy: sortBy,
      limit: limit,
    );
  }

  /// Factory for this month with default sort by quantity
  factory TopProductsParams.thisMonth({
    ProductReportSortType sortBy = ProductReportSortType.quantity,
    int limit = 10,
  }) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    return TopProductsParams(
      from: startOfMonth,
      to: endOfMonth,
      sortBy: sortBy,
      limit: limit,
    );
  }

  @override
  List<Object?> get props => [from, to, sortBy, limit];
}
