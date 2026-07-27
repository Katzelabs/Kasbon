import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/customer_analytics.dart';
import '../repositories/analytics_repository.dart';

/// Use case to get the highest-spending customers for a date range.
class GetTopCustomers
    extends UseCase<List<CustomerAnalytics>, TopCustomersParams> {
  final AnalyticsRepository repository;

  GetTopCustomers(this.repository);

  @override
  Future<Either<Failure, List<CustomerAnalytics>>> call(
      TopCustomersParams params) async {
    return await repository.getTopCustomers(
      from: params.from,
      to: params.to,
      limit: params.limit,
    );
  }
}

/// Parameters for the top customers query.
class TopCustomersParams extends Equatable {
  final DateTime from;
  final DateTime to;
  final int limit;

  const TopCustomersParams({
    required this.from,
    required this.to,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [from, to, limit];
}
