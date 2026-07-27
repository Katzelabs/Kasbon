import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/period_comparison.dart';
import '../entities/report_filter.dart';
import '../repositories/report_repository.dart';

/// Use case comparing the selected period against the one immediately before
/// it.
///
/// Deliberately built from two `get_sales_summary` calls rather than a
/// dedicated RPC: the transaction date range is already indexed, so a second
/// round trip is cheaper than adding and maintaining more SQL. The two calls
/// run concurrently.
class ComparePeriods extends UseCase<PeriodComparison, ComparePeriodsParams> {
  final ReportRepository repository;

  ComparePeriods(this.repository);

  @override
  Future<Either<Failure, PeriodComparison>> call(
      ComparePeriodsParams params) async {
    final results = await Future.wait([
      repository.getSalesSummary(
        from: params.from,
        to: params.to,
        filter: params.filter,
      ),
      repository.getSalesSummary(
        from: params.previousFrom,
        to: params.previousTo,
        filter: params.filter,
      ),
    ]);

    final current = results[0];
    final previous = results[1];

    // Surface whichever call failed; a comparison with half its data missing
    // would be worse than no comparison.
    return current.fold(
      Left.new,
      (currentSummary) => previous.fold(
        Left.new,
        (previousSummary) => Right(
          PeriodComparison(
            current: currentSummary,
            previous: previousSummary,
          ),
        ),
      ),
    );
  }
}

/// Parameters for a period-over-period comparison.
class ComparePeriodsParams extends Equatable {
  final DateTime from;
  final DateTime to;
  final ReportFilter filter;

  const ComparePeriodsParams({
    required this.from,
    required this.to,
    this.filter = ReportFilter.none,
  });

  /// Length of the selected period.
  Duration get periodLength => to.difference(from);

  /// Start of the preceding period - the same length, ending where the
  /// selected period begins.
  DateTime get previousFrom => from.subtract(periodLength);

  /// End of the preceding period, exclusive. This is the selected period's
  /// start, matching the RPC's half-open `[from, to)` range so no transaction
  /// is counted in both periods.
  DateTime get previousTo => from;

  @override
  List<Object?> get props => [from, to, filter];
}
