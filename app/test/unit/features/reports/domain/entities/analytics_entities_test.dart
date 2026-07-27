import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/reports/domain/entities/heatmap_cell.dart';
import 'package:kasbon_pos/features/reports/domain/entities/period_comparison.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_movement.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_summary.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';

SalesTrendPoint _point(DateTime bucket, double revenue) => SalesTrendPoint(
      bucketStart: bucket,
      granularity: TrendGranularity.day,
      revenue: revenue,
      profit: revenue / 4,
      transactionCount: 1,
      itemsSold: 2,
    );

HeatmapCell _cell(int day, int hour, double revenue, {int count = 1}) =>
    HeatmapCell(
      dayOfWeek: day,
      hourOfDay: hour,
      transactionCount: count,
      revenue: revenue,
    );

ProductMovement _movement({
  required String name,
  required int stock,
  required int sold,
  double stockValue = 0,
  double? turnover,
  bool slow = false,
}) =>
    ProductMovement(
      id: name,
      name: name,
      sku: name,
      currentStock: stock,
      costPrice: 1000,
      stockValue: stockValue,
      quantitySold: sold,
      totalRevenue: sold * 2000,
      totalCogs: sold * 1000,
      totalProfit: sold * 1000,
      lastSoldAt: null,
      turnoverRatio: turnover,
      daysOfSupply: null,
      isSlowMoving: slow,
    );

void main() {
  group('SalesTrendPointX.fillGaps', () {
    test('inserts zero buckets for days with no sales', () {
      // The RPC omits empty buckets entirely, so the chart would otherwise
      // connect 20 Jul straight to 22 Jul and hide the quiet day.
      final sparse = [
        _point(DateTime(2026, 7, 20), 47000),
        _point(DateTime(2026, 7, 22), 133000),
      ];

      final filled = sparse.fillGaps(
        from: DateTime(2026, 7, 20),
        to: DateTime(2026, 7, 23),
        granularity: TrendGranularity.day,
      );

      expect(filled.length, 3);
      expect(filled[0].revenue, 47000);
      expect(filled[1].revenue, 0);
      expect(filled[1].bucketStart, DateTime(2026, 7, 21));
      expect(filled[2].revenue, 133000);
    });

    test('treats the range as half-open, excluding the end bucket', () {
      final filled = <SalesTrendPoint>[].fillGaps(
        from: DateTime(2026, 7, 20),
        to: DateTime(2026, 7, 23),
        granularity: TrendGranularity.day,
      );

      expect(filled.length, 3);
      expect(filled.last.bucketStart, DateTime(2026, 7, 22));
    });

    test('aligns week buckets to Monday, matching date_trunc', () {
      // 2026-07-22 is a Wednesday; its week bucket must start Monday 20 Jul.
      final filled = <SalesTrendPoint>[].fillGaps(
        from: DateTime(2026, 7, 22),
        to: DateTime(2026, 8, 5),
        granularity: TrendGranularity.week,
      );

      expect(filled.first.bucketStart, DateTime(2026, 7, 20));
      expect(filled.first.bucketStart.weekday, DateTime.monday);
      for (final point in filled) {
        expect(point.bucketStart.weekday, DateTime.monday);
      }
    });

    test('aligns month buckets to the first of the month', () {
      final filled = <SalesTrendPoint>[].fillGaps(
        from: DateTime(2026, 6, 15),
        to: DateTime(2026, 9, 1),
        granularity: TrendGranularity.month,
      );

      expect(filled.map((p) => p.bucketStart), [
        DateTime(2026, 6),
        DateTime(2026, 7),
        DateTime(2026, 8),
      ]);
    });

    test('crosses a month boundary without skipping or repeating a day', () {
      final filled = <SalesTrendPoint>[].fillGaps(
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 8, 2),
        granularity: TrendGranularity.day,
      );

      expect(filled.map((p) => p.bucketStart), [
        DateTime(2026, 7, 30),
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
      ]);
    });

    test('returns empty for an inverted or zero-length range', () {
      final points = [_point(DateTime(2026, 7, 20), 1000)];

      expect(
        points.fillGaps(
          from: DateTime(2026, 7, 22),
          to: DateTime(2026, 7, 20),
          granularity: TrendGranularity.day,
        ),
        isEmpty,
      );
      expect(
        points.fillGaps(
          from: DateTime(2026, 7, 20),
          to: DateTime(2026, 7, 20),
          granularity: TrendGranularity.day,
        ),
        isEmpty,
      );
    });

    test('aggregates series totals', () {
      final points = [
        _point(DateTime(2026, 7, 20), 40000),
        _point(DateTime(2026, 7, 21), 60000),
      ];

      expect(points.totalRevenue, 100000);
      expect(points.totalProfit, 25000);
      expect(points.maxRevenue, 60000);
      expect(<SalesTrendPoint>[].maxRevenue, 0);
    });
  });

  group('HourlyHeatmap', () {
    final heatmap = HourlyHeatmap([
      _cell(1, 14, 180000, count: 3),
      _cell(3, 14, 223000, count: 3),
      _cell(5, 14, 268500, count: 4),
      _cell(6, 22, 38000),
    ]);

    test('reads a populated cell and returns zero for an empty one', () {
      expect(heatmap.revenueAt(1, 14), 180000);
      expect(heatmap.countAt(1, 14), 3);
      expect(heatmap.revenueAt(2, 9), 0);
      expect(heatmap.cellAt(2, 9), isNull);
    });

    test('scales intensity against the busiest cell', () {
      expect(heatmap.intensityAt(5, 14), 1.0);
      expect(heatmap.intensityAt(1, 14), closeTo(180000 / 268500, 0.0001));
      expect(heatmap.intensityAt(2, 9), 0);
    });

    test(
        'returns zero intensity for an empty grid rather than dividing by zero',
        () {
      expect(HourlyHeatmap.empty.intensityAt(1, 14), 0);
      expect(HourlyHeatmap.empty.maxCellRevenue, 0);
    });

    test('reports all seven weekdays even when some had no sales', () {
      final byDay = heatmap.revenueByDay;

      expect(byDay.keys.toList()..sort(), [1, 2, 3, 4, 5, 6, 7]);
      expect(byDay[2], 0);
      expect(byDay[6], 38000, reason: 'day 6 has one cell at 22:00');
    });

    test('reports all 24 hours even when most had no sales', () {
      final byHour = heatmap.revenueByHour;

      expect(byHour.length, 24);
      expect(byHour[0], 0);
      expect(byHour[14], 180000 + 223000 + 268500);
      expect(byHour[22], 38000);
    });

    test('finds the peak cell, busiest day and busiest hour', () {
      expect(heatmap.peakCell?.dayOfWeek, 5);
      expect(heatmap.peakCell?.revenue, 268500);
      expect(heatmap.busiestDay, 5);
      expect(heatmap.busiestHour, 14);
    });

    test('excludes zero-revenue days from the quietest day', () {
      // A day with no sales is not "the quietest trading day" - it is a day the
      // shop did no business, which is a different fact.
      expect(heatmap.quietestDay, 6);
    });

    test('ranks the top hours and skips empty ones', () {
      expect(heatmap.topHours(count: 3), [14, 22]);
    });

    test('returns nulls and empties for an empty heatmap', () {
      expect(HourlyHeatmap.empty.peakCell, isNull);
      expect(HourlyHeatmap.empty.busiestDay, isNull);
      expect(HourlyHeatmap.empty.busiestHour, isNull);
      expect(HourlyHeatmap.empty.quietestDay, isNull);
      expect(HourlyHeatmap.empty.topHours(), isEmpty);
      expect(HourlyHeatmap.empty.isEmpty, isTrue);
    });

    test('totals revenue and transactions across cells', () {
      expect(heatmap.totalRevenue, 180000 + 223000 + 268500 + 38000);
      expect(heatmap.totalTransactions, 11);
    });
  });

  group('PeriodComparison', () {
    SalesSummary summary(double revenue, {int txns = 10, double profit = 0}) =>
        SalesSummary(
          totalRevenue: revenue,
          totalProfit: profit,
          transactionCount: txns,
          itemsSold: txns * 2,
          periodStart: DateTime(2026, 7),
          periodEnd: DateTime(2026, 8),
        );

    test('computes an increase', () {
      final comparison = PeriodComparison(
        current: summary(150000),
        previous: summary(100000),
      );

      expect(comparison.revenue.delta, 50000);
      expect(comparison.revenue.percentChange, 50.0);
      expect(comparison.revenue.direction, ChangeDirection.up);
      expect(comparison.revenue.isImprovement, isTrue);
      expect(comparison.hasBaseline, isTrue);
    });

    test('computes a decrease', () {
      final comparison = PeriodComparison(
        current: summary(75000),
        previous: summary(100000),
      );

      expect(comparison.revenue.delta, -25000);
      expect(comparison.revenue.percentChange, -25.0);
      expect(comparison.revenue.direction, ChangeDirection.down);
      expect(comparison.revenue.isImprovement, isFalse);
    });

    test('reports a flat period', () {
      final comparison = PeriodComparison(
        current: summary(100000),
        previous: summary(100000),
      );

      expect(comparison.revenue.delta, 0);
      expect(comparison.revenue.percentChange, 0);
      expect(comparison.revenue.direction, ChangeDirection.flat);
    });

    test('returns a null percentage when there is no baseline', () {
      // Growth from zero is undefined, not infinite - the UI shows "baru".
      final comparison = PeriodComparison(
        current: summary(120000),
        previous: summary(0, txns: 0),
      );

      expect(comparison.revenue.percentChange, isNull);
      expect(comparison.revenue.isNewActivity, isTrue);
      expect(comparison.revenue.delta, 120000);
      expect(comparison.hasBaseline, isFalse);
    });

    test('handles both periods being empty', () {
      final comparison = PeriodComparison(
        current: summary(0, txns: 0),
        previous: summary(0, txns: 0),
      );

      expect(comparison.revenue.percentChange, isNull);
      expect(comparison.revenue.isNewActivity, isFalse);
      expect(comparison.revenue.direction, ChangeDirection.flat);
    });

    test('compares transaction counts and profit alongside revenue', () {
      final comparison = PeriodComparison(
        current: summary(150000, txns: 20, profit: 50000),
        previous: summary(100000, txns: 10, profit: 25000),
      );

      expect(comparison.transactionCount.delta, 10);
      expect(comparison.transactionCount.percentChange, 100.0);
      expect(comparison.profit.percentChange, 100.0);
      expect(comparison.itemsSold.delta, 20);
    });

    test('handles a recovery from a negative baseline', () {
      // Profit can be negative; percentage change must use the magnitude of the
      // baseline so a loss turning into a gain reads as an improvement.
      final comparison = PeriodComparison(
        current: summary(0, txns: 1, profit: 5000),
        previous: summary(0, txns: 1, profit: -5000),
      );

      expect(comparison.profit.delta, 10000);
      expect(comparison.profit.percentChange, 200.0);
      expect(comparison.profit.direction, ChangeDirection.up);
    });
  });

  group('ProductMovementX', () {
    final products = [
      _movement(
          name: 'Cepat', stock: 5, sold: 100, stockValue: 5000, turnover: 8),
      _movement(
          name: 'Mati', stock: 20, sold: 0, stockValue: 200000, slow: true),
      _movement(
          name: 'Lambat',
          stock: 10,
          sold: 2,
          stockValue: 100000,
          turnover: 0.1,
          slow: true),
      _movement(name: 'Habis', stock: 0, sold: 0, stockValue: 0),
    ];

    test('ranks by turnover descending with nulls last', () {
      final ranked = products.byTurnoverDesc;

      // Cepat (8.0) then Lambat (0.1); the two null-turnover products fill the
      // remaining slots, tie-broken by name rather than being dropped.
      expect(ranked.map((p) => p.name), ['Cepat', 'Lambat', 'Habis', 'Mati']);
      expect(ranked.length, products.length);
      expect(ranked.sublist(2).every((p) => p.turnoverRatio == null), isTrue);
    });

    test('puts dead stock ahead of merely overstocked in the slow list', () {
      final slow = products.slowMoving;

      expect(slow.map((p) => p.name), ['Mati', 'Lambat']);
    });

    test('excludes out-of-stock products from dead stock', () {
      expect(products.deadStock.map((p) => p.name), ['Mati']);
    });

    test('sums capital tied up in slow movers only', () {
      expect(products.tiedUpCapital, 300000);
      expect(products.totalStockValue, 305000);
    });
  });
}
