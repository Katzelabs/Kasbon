import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/business_time.dart';
import '../entities/profit_summary.dart';
import '../repositories/profit_report_repository.dart';

/// Use case to get profit summary for a date range
class GetProfitSummary extends UseCase<ProfitSummary, DateRangeParams> {
  final ProfitReportRepository repository;

  GetProfitSummary(this.repository);

  @override
  Future<Either<Failure, ProfitSummary>> call(DateRangeParams params) async {
    return await repository.getProfitByDateRange(
      from: params.from,
      to: params.to,
    );
  }
}

/// Parameters for date range queries
class DateRangeParams extends Equatable {
  final DateTime from;
  final DateTime to;

  const DateRangeParams({
    required this.from,
    required this.to,
  });

  /// Factory for today
  ///
  /// Boundaries are business wall-clock (see [BusinessTime]), not device-local:
  /// on a device set to another zone, `DateTime.now()` can name a different day
  /// than the shop is actually trading in.
  factory DateRangeParams.today() {
    final startOfDay = BusinessTime.startOfDay();
    return DateRangeParams(
      from: startOfDay,
      to: DateTime(startOfDay.year, startOfDay.month, startOfDay.day + 1),
    );
  }

  /// Factory for this month
  factory DateRangeParams.thisMonth() {
    final startOfMonth = BusinessTime.startOfMonth();
    return DateRangeParams(
      from: startOfMonth,
      to: DateTime(startOfMonth.year, startOfMonth.month + 1),
    );
  }

  /// Factory for this week (starting Monday)
  factory DateRangeParams.thisWeek() {
    final startOfWeek = BusinessTime.startOfWeek();
    return DateRangeParams(
      from: startOfWeek,
      to: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 7),
    );
  }

  @override
  List<Object?> get props => [from, to];
}
