import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/heatmap_cell.dart';
import '../repositories/analytics_repository.dart';
import 'get_profit_summary.dart';

/// Use case to get the weekday-by-hour sales grid.
///
/// The returned [HourlyHeatmap] also exposes the peak-hours and day-of-week
/// analytics, so a single call backs all three views.
class GetHourlyHeatmap extends UseCase<HourlyHeatmap, DateRangeParams> {
  final AnalyticsRepository repository;

  GetHourlyHeatmap(this.repository);

  @override
  Future<Either<Failure, HourlyHeatmap>> call(DateRangeParams params) async {
    return await repository.getHourlyHeatmap(
      from: params.from,
      to: params.to,
    );
  }
}
