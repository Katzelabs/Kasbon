import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
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
  factory DateRangeParams.today() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return DateRangeParams(from: startOfDay, to: endOfDay);
  }

  /// Factory for this month
  factory DateRangeParams.thisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    return DateRangeParams(from: startOfMonth, to: endOfMonth);
  }

  /// Factory for this week (starting Monday)
  factory DateRangeParams.thisWeek() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final startOfWeek = DateTime(now.year, now.month, now.day - dayOfWeek + 1);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return DateRangeParams(from: startOfWeek, to: endOfWeek);
  }

  @override
  List<Object?> get props => [from, to];
}
