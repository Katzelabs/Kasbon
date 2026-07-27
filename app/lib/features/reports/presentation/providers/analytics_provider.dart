import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/category_slice.dart';
import '../../domain/entities/customer_analytics.dart';
import '../../domain/entities/heatmap_cell.dart';
import '../../domain/entities/payment_slice.dart';
import '../../domain/entities/period_comparison.dart';
import '../../domain/entities/product_movement.dart';
import '../../domain/entities/sales_trend_point.dart';
import '../../domain/usecases/compare_periods.dart';
import '../../domain/usecases/get_category_distribution.dart';
import '../../domain/usecases/get_hourly_heatmap.dart';
import '../../domain/usecases/get_payment_distribution.dart';
import '../../domain/usecases/get_product_movement.dart';
import '../../domain/usecases/get_sales_trend.dart';
import '../../domain/usecases/get_top_customers.dart';
import 'date_range_provider.dart';
import 'report_filter_provider.dart';

/// Bucket size for the trend chart, toggled by the user.
///
/// Defaults to null, meaning "follow the date range" - see
/// [effectiveTrendGranularityProvider].
final trendGranularityProvider =
    StateProvider<TrendGranularity?>((ref) => null);

/// The granularity actually used for the trend query.
///
/// With no explicit choice this derives a sensible bucket from the range, so
/// picking "Bulan Ini" does not render 31 cramped daily points on a phone.
final effectiveTrendGranularityProvider = Provider<TrendGranularity>((ref) {
  final explicit = ref.watch(trendGranularityProvider);
  if (explicit != null) return explicit;

  final dateRange = ref.watch(dateRangeProvider);
  return SalesTrendParams.auto(
    from: dateRange.from,
    to: dateRange.to,
  ).granularity;
});

/// Sales and profit trend for the selected range, gaps filled so the chart's
/// x-axis is continuous.
final salesTrendProvider =
    FutureProvider.autoDispose<List<SalesTrendPoint>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final filter = ref.watch(reportFilterProvider);
  final granularity = ref.watch(effectiveTrendGranularityProvider);

  final result = await getIt<GetSalesTrend>()(SalesTrendParams(
    from: dateRange.from,
    to: dateRange.to,
    granularity: granularity,
    filter: filter,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (points) => points.fillGaps(
      from: dateRange.from,
      to: dateRange.to,
      granularity: granularity,
    ),
  );
});

/// Revenue share per product category.
final categoryDistributionProvider =
    FutureProvider.autoDispose<List<CategorySlice>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final filter = ref.watch(reportFilterProvider);

  final result = await getIt<GetCategoryDistribution>()(AnalyticsRangeParams(
    from: dateRange.from,
    to: dateRange.to,
    filter: filter,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (slices) => slices,
  );
});

/// Transaction share per payment method.
final paymentDistributionProvider =
    FutureProvider.autoDispose<List<PaymentSlice>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);

  final result = await getIt<GetPaymentDistribution>()(dateRange.toParams());

  return result.fold(
    (failure) => throw Exception(failure.message),
    (slices) => slices,
  );
});

/// Weekday-by-hour sales grid, which also backs the peak-hours and
/// day-of-week views.
final hourlyHeatmapProvider =
    FutureProvider.autoDispose<HourlyHeatmap>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);

  final result = await getIt<GetHourlyHeatmap>()(dateRange.toParams());

  return result.fold(
    (failure) => throw Exception(failure.message),
    (heatmap) => heatmap,
  );
});

/// Highest-spending customers for the selected range.
final topCustomersProvider =
    FutureProvider.autoDispose<List<CustomerAnalytics>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);

  final result = await getIt<GetTopCustomers>()(TopCustomersParams(
    from: dateRange.from,
    to: dateRange.to,
    limit: 20,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (customers) => customers,
  );
});

/// Inventory movement for every active product. The turnover and slow-moving
/// views both read from this one provider.
final productMovementProvider =
    FutureProvider.autoDispose<List<ProductMovement>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);

  final result = await getIt<GetProductMovement>()(ProductMovementParams(
    from: dateRange.from,
    to: dateRange.to,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (movements) => movements,
  );
});

/// Selected period compared against the preceding period of equal length.
final periodComparisonProvider =
    FutureProvider.autoDispose<PeriodComparison>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final filter = ref.watch(reportFilterProvider);

  final result = await getIt<ComparePeriods>()(ComparePeriodsParams(
    from: dateRange.from,
    to: dateRange.to,
    filter: filter,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (comparison) => comparison,
  );
});

/// Invalidate every analytics provider at once, for pull-to-refresh.
void invalidateAnalytics(WidgetRef ref) {
  ref
    ..invalidate(salesTrendProvider)
    ..invalidate(categoryDistributionProvider)
    ..invalidate(paymentDistributionProvider)
    ..invalidate(hourlyHeatmapProvider)
    ..invalidate(topCustomersProvider)
    ..invalidate(productMovementProvider)
    ..invalidate(periodComparisonProvider);
}
