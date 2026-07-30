import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/utils/business_time.dart';
import '../../../reports/domain/entities/payment_slice.dart';
import '../../../reports/domain/entities/product_report.dart';
import '../../../reports/domain/entities/sales_trend_point.dart';
import '../../../reports/domain/repositories/report_repository.dart';
// DateRangeParams lives beside the profit summary use case, which is where the
// reports providers take it from too.
import '../../../reports/domain/usecases/get_profit_summary.dart';
import '../../../reports/domain/usecases/get_payment_distribution.dart';
import '../../../reports/domain/usecases/get_sales_trend.dart';
import '../../../reports/domain/usecases/get_top_products.dart';

/// Length of the dashboard's analytics window, in days, today included.
const int dashboardTrendDays = 7;

/// How many products the dashboard's top-sellers block *fetches*.
///
/// Eight, not the reports' twenty: this is a glance. How many of the eight are
/// actually rendered is a layout decision, not a data one - see
/// `DashboardTopProductsCard.maxRows`, which shows five in a narrow column and
/// all eight in the desktop layout, where the card is 900dp wide and five rows
/// leave it mostly empty.
///
/// Fetching the larger number unconditionally keeps the tier out of the provider:
/// three extra rows cost nothing, and a provider that read the breakpoint would
/// need a `BuildContext` it has no business holding.
const int dashboardTopProductsLimit = 8;

/// The rolling window every dashboard analytics block reads.
///
/// Fixed at [dashboardTrendDays] days ending today, deliberately. The reports
/// screens own a user-selected range; a dashboard that inherited it would
/// answer a different question depending on what someone last looked at in
/// Laporan, and the figures would stop agreeing with the "hari ini" cards
/// directly above them. The dashboard's question is always the same one: how is
/// the week going.
@immutable
class DashboardAnalyticsWindow {
  /// First day of the window, as business wall-clock midnight. Inclusive.
  final DateTime from;

  /// Exclusive end - midnight *after* today, so today counts. Matches the
  /// half-open range the report RPCs take.
  final DateTime to;

  const DashboardAnalyticsWindow({required this.from, required this.to});

  /// The [days]-day window ending with today, on the shop's clock.
  ///
  /// Business wall-clock rather than `DateTime.now()`: on a device set to
  /// another zone those name different days, and the window would drift out of
  /// step with the summary cards above it. See [BusinessTime].
  factory DashboardAnalyticsWindow.trailingDays(
    int days, {
    DateTime? reference,
  }) {
    final today = BusinessTime.startOfDay(reference);
    return DashboardAnalyticsWindow(
      from: DateTime(today.year, today.month, today.day - (days - 1)),
      to: DateTime(today.year, today.month, today.day + 1),
    );
  }

  /// The window as a readable range - "24 Jul - 30 Jul".
  ///
  /// Worth stating on screen: the dashboard's cards say "Hari Ini" and the
  /// analytics band covers a week, and without a label the two read as the same
  /// period disagreeing with each other.
  String get label {
    final format = DateFormat('d MMM', 'id_ID');
    // `to` is exclusive, so the last day the data covers is the day before it.
    final lastDay = DateTime(to.year, to.month, to.day - 1);
    return '${format.format(from)} - ${format.format(lastDay)}';
  }
}

/// The window the analytics blocks share.
///
/// `autoDispose` on purpose: a cached-forever provider would pin the window it
/// was first built with, and a till left open overnight would keep charting
/// yesterday's week.
final dashboardAnalyticsWindowProvider =
    Provider.autoDispose<DashboardAnalyticsWindow>(
  (ref) => DashboardAnalyticsWindow.trailingDays(dashboardTrendDays),
);

/// Daily revenue and profit across the window, gaps filled.
///
/// The RPC omits days with no sales entirely; without [SalesTrendPointX.fillGaps]
/// a closed Sunday would vanish from the x-axis instead of reading as a dip,
/// and a quiet week would render as a shorter, healthier-looking chart.
final dashboardSalesTrendProvider =
    FutureProvider.autoDispose<List<SalesTrendPoint>>((ref) async {
  final window = ref.watch(dashboardAnalyticsWindowProvider);

  final result = await getIt<GetSalesTrend>()(SalesTrendParams(
    from: window.from,
    to: window.to,
    granularity: TrendGranularity.day,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (points) => points.fillGaps(
      from: window.from,
      to: window.to,
      granularity: TrendGranularity.day,
    ),
  );
});

/// Best-selling products of the window, by revenue.
///
/// Revenue rather than units: a dashboard row showing "500 plastic bags" above
/// "3 gas cylinders" ranks the noise first.
final dashboardTopProductsProvider =
    FutureProvider.autoDispose<List<ProductReport>>((ref) async {
  final window = ref.watch(dashboardAnalyticsWindowProvider);

  final result = await getIt<GetTopProducts>()(TopProductsParams(
    from: window.from,
    to: window.to,
    sortBy: ProductReportSortType.revenue,
    limit: dashboardTopProductsLimit,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

/// Turnover split by payment method across the window.
///
/// Carries `debt` as its own slice, which is the point of showing it here at
/// all - a shop whose week looks strong on revenue but is a third hutang is in
/// a different position from one that took cash, and nothing else on the
/// dashboard says so.
final dashboardPaymentMixProvider =
    FutureProvider.autoDispose<List<PaymentSlice>>((ref) async {
  final window = ref.watch(dashboardAnalyticsWindowProvider);

  final result = await getIt<GetPaymentDistribution>()(DateRangeParams(
    from: window.from,
    to: window.to,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (slices) => slices,
  );
});

/// Invalidate every analytics block at once, for pull-to-refresh.
///
/// The window provider is invalidated first and deliberately: refreshing after
/// midnight should move the window, not re-fetch yesterday's one.
void invalidateDashboardAnalytics(WidgetRef ref) {
  ref
    ..invalidate(dashboardAnalyticsWindowProvider)
    ..invalidate(dashboardSalesTrendProvider)
    ..invalidate(dashboardTopProductsProvider)
    ..invalidate(dashboardPaymentMixProvider);
}
