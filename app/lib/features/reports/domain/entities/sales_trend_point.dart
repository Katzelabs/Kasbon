import 'package:equatable/equatable.dart';

import 'report_filter.dart';

/// Bucket size for the sales/profit trend chart.
enum TrendGranularity {
  day('day', 'Harian'),
  week('week', 'Mingguan'),
  month('month', 'Bulanan');

  const TrendGranularity(this.wireValue, this.label);

  /// Value sent to `get_sales_trend(p_granularity)`.
  final String wireValue;

  /// Display label in Bahasa Indonesia.
  final String label;

  static TrendGranularity fromWire(String? value) {
    for (final granularity in TrendGranularity.values) {
      if (granularity.wireValue == value) return granularity;
    }
    return TrendGranularity.day;
  }
}

/// A single point on the sales/profit trend chart.
///
/// The RPC omits buckets with no sales entirely; use
/// [SalesTrendPointX.fillGaps] to produce a continuous series for the chart.
class SalesTrendPoint extends Equatable {
  /// Start of the bucket, in the shop's local time zone.
  final DateTime bucketStart;

  /// Bucket size this point was aggregated at.
  final TrendGranularity granularity;

  /// Revenue for the bucket. See [revenueBasis] for how it was computed.
  final double revenue;

  /// Gross profit for the bucket, always computed from line items.
  final double profit;

  /// Number of transactions in the bucket.
  final int transactionCount;

  /// Number of items sold in the bucket.
  final int itemsSold;

  /// How [revenue] was computed - see [RevenueBasis].
  final RevenueBasis revenueBasis;

  const SalesTrendPoint({
    required this.bucketStart,
    required this.granularity,
    required this.revenue,
    required this.profit,
    required this.transactionCount,
    required this.itemsSold,
    this.revenueBasis = RevenueBasis.transaction,
  });

  /// An explicit zero bucket, used when filling gaps in the series.
  factory SalesTrendPoint.empty(
    DateTime bucketStart,
    TrendGranularity granularity, {
    RevenueBasis revenueBasis = RevenueBasis.transaction,
  }) {
    return SalesTrendPoint(
      bucketStart: bucketStart,
      granularity: granularity,
      revenue: 0,
      profit: 0,
      transactionCount: 0,
      itemsSold: 0,
      revenueBasis: revenueBasis,
    );
  }

  /// Profit as a percentage of revenue for this bucket.
  double get profitMargin {
    if (revenue == 0) return 0;
    return (profit / revenue) * 100;
  }

  /// Average transaction value for this bucket.
  double get averageTransactionValue {
    if (transactionCount == 0) return 0;
    return revenue / transactionCount;
  }

  @override
  List<Object?> get props => [
        bucketStart,
        granularity,
        revenue,
        profit,
        transactionCount,
        itemsSold,
        revenueBasis,
      ];
}

/// Series-level helpers for a list of trend points.
extension SalesTrendPointX on List<SalesTrendPoint> {
  double get totalRevenue => fold(0.0, (sum, p) => sum + p.revenue);

  double get totalProfit => fold(0.0, (sum, p) => sum + p.profit);

  /// Largest revenue in the series, used to scale the chart's y-axis.
  double get maxRevenue =>
      isEmpty ? 0 : map((p) => p.revenue).reduce((a, b) => a > b ? a : b);

  /// Largest profit in the series. Can be negative if every bucket lost money.
  double get maxProfit =>
      isEmpty ? 0 : map((p) => p.profit).reduce((a, b) => a > b ? a : b);

  /// Insert zero-valued buckets so the chart's x-axis has no holes.
  ///
  /// [from] is inclusive and [to] exclusive, matching the RPC's range. Week
  /// buckets are aligned to Monday and month buckets to the 1st, mirroring
  /// Postgres `date_trunc`.
  List<SalesTrendPoint> fillGaps({
    required DateTime from,
    required DateTime to,
    required TrendGranularity granularity,
  }) {
    if (to.isBefore(from) || to.isAtSameMomentAs(from)) return const [];

    final byBucket = {for (final point in this) point.bucketStart: point};
    final basis = isEmpty ? RevenueBasis.transaction : first.revenueBasis;
    final filled = <SalesTrendPoint>[];

    var cursor = _truncate(from, granularity);
    while (cursor.isBefore(to)) {
      filled.add(
        byBucket[cursor] ??
            SalesTrendPoint.empty(cursor, granularity, revenueBasis: basis),
      );
      cursor = _advance(cursor, granularity);
    }
    return filled;
  }

  static DateTime _truncate(DateTime date, TrendGranularity granularity) {
    switch (granularity) {
      case TrendGranularity.day:
        return DateTime(date.year, date.month, date.day);
      case TrendGranularity.week:
        // DateTime.weekday is 1 (Monday) to 7 (Sunday), matching Postgres
        // date_trunc('week', ...) which also starts weeks on Monday.
        final monday = date.subtract(Duration(days: date.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case TrendGranularity.month:
        return DateTime(date.year, date.month);
    }
  }

  static DateTime _advance(DateTime date, TrendGranularity granularity) {
    switch (granularity) {
      case TrendGranularity.day:
        // Reconstructing via the constructor rather than adding a Duration
        // keeps the cursor on midnight local time across a DST shift.
        return DateTime(date.year, date.month, date.day + 1);
      case TrendGranularity.week:
        return DateTime(date.year, date.month, date.day + 7);
      case TrendGranularity.month:
        return DateTime(date.year, date.month + 1);
    }
  }
}
