import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/features/reports/domain/entities/heatmap_cell.dart';
import 'package:kasbon_pos/features/reports/domain/entities/period_comparison.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_summary.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/day_of_week_bar_chart.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/distribution_pie_chart.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/hourly_sales_heatmap.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/peak_hours_card.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/period_comparison_card.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/sales_trend_line_chart.dart';

/// Wrap a widget in the minimum scaffolding needed to pump it.
///
/// Charts size themselves to their parent, so an unbounded parent would throw
/// a layout error that has nothing to do with the widget under test.
Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 400, child: child),
      ),
    ),
  );
}

SalesTrendPoint _point(int day, double revenue, {double? profit}) =>
    SalesTrendPoint(
      bucketStart: DateTime(2026, 7, day),
      granularity: TrendGranularity.day,
      revenue: revenue,
      profit: profit ?? revenue / 4,
      transactionCount: 2,
      itemsSold: 5,
    );

SalesSummary _summary(double revenue, {int txns = 10}) => SalesSummary(
      totalRevenue: revenue,
      totalProfit: revenue / 4,
      transactionCount: txns,
      itemsSold: txns * 2,
      periodStart: DateTime(2026, 7),
      periodEnd: DateTime(2026, 8),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('SalesTrendLineChart', () {
    testWidgets('shows an empty message rather than an axis with no data',
        (tester) async {
      await tester.pumpWidget(_host(const SalesTrendLineChart(points: [])));

      expect(find.text('Tidak ada data penjualan'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('renders a chart for a normal series', (tester) async {
      await tester.pumpWidget(_host(SalesTrendLineChart(
        points: [
          _point(20, 47000),
          _point(21, 0),
          _point(22, 133000),
        ],
      )));

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders a single point without throwing', (tester) async {
      await tester.pumpWidget(_host(SalesTrendLineChart(
        points: [_point(20, 47000)],
      )));

      expect(find.byType(LineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives an all-zero series', (tester) async {
      // maxY would be zero here, which fl_chart cannot scale to - the widget
      // has to floor it or the chart throws.
      await tester.pumpWidget(_host(SalesTrendLineChart(
        points: [_point(20, 0), _point(21, 0)],
      )));

      expect(find.byType(LineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles negative profit without throwing', (tester) async {
      await tester.pumpWidget(_host(SalesTrendLineChart(
        points: [
          _point(20, 50000, profit: -20000),
          _point(21, 60000, profit: 15000),
        ],
      )));

      expect(find.byType(LineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles a large series without throwing', (tester) async {
      await tester.pumpWidget(_host(SalesTrendLineChart(
        points: [
          for (var day = 1; day <= 31; day++)
            _point(day, (day * 1000).toDouble()),
        ],
      )));

      expect(find.byType(LineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('legend labels both lines, and only revenue when profit is off',
        (tester) async {
      await tester.pumpWidget(_host(const SalesTrendLegend()));
      expect(find.text('Pendapatan'), findsOneWidget);
      expect(find.text('Laba'), findsOneWidget);

      await tester.pumpWidget(_host(const SalesTrendLegend(showProfit: false)));
      expect(find.text('Pendapatan'), findsOneWidget);
      expect(find.text('Laba'), findsNothing);
    });
  });

  group('DistributionPieChart', () {
    const slices = [
      PieSliceData(label: 'Makanan', value: 682500, color: Colors.orange),
      PieSliceData(label: 'Minuman', value: 279500, color: Colors.blue),
    ];

    testWidgets('shows an empty message for no slices', (tester) async {
      await tester.pumpWidget(_host(const DistributionPieChart(slices: [])));

      expect(find.text('Tidak ada data'), findsOneWidget);
      expect(find.byType(PieChart), findsNothing);
    });

    testWidgets('shows an empty message when every slice is zero',
        (tester) async {
      // A zero total would divide by zero when computing percentages.
      await tester.pumpWidget(_host(const DistributionPieChart(
        slices: [
          PieSliceData(label: 'Makanan', value: 0, color: Colors.orange),
        ],
      )));

      expect(find.text('Tidak ada data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a chart and a legend row per slice', (tester) async {
      await tester.pumpWidget(_host(const DistributionPieChart(
        slices: slices,
      )));

      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('Makanan'), findsOneWidget);
      expect(find.text('Minuman'), findsOneWidget);
    });

    testWidgets('legend percentages sum to 100', (tester) async {
      await tester.pumpWidget(_host(const DistributionPieChart(
        slices: [
          PieSliceData(label: 'A', value: 750, color: Colors.red),
          PieSliceData(label: 'B', value: 250, color: Colors.green),
        ],
      )));

      expect(find.text('75.0%'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
    });

    testWidgets('tapping a legend row highlights it in the centre readout',
        (tester) async {
      await tester
          .pumpWidget(_host(const DistributionPieChart(slices: slices)));

      // Before tapping, the centre shows the series total label.
      expect(find.text('Total'), findsOneWidget);

      await tester.tap(find.text('Minuman'));
      await tester.pumpAndSettle();

      // The centre readout now names the selected slice instead.
      expect(find.text('Total'), findsNothing);
      expect(find.text('Minuman'), findsNWidgets(2));
    });
  });

  group('HourlySalesHeatmap', () {
    const populated = HourlyHeatmap([
      HeatmapCell(
        dayOfWeek: 1,
        hourOfDay: 14,
        transactionCount: 3,
        revenue: 180000,
      ),
      HeatmapCell(
        dayOfWeek: 5,
        hourOfDay: 9,
        transactionCount: 4,
        revenue: 268500,
      ),
    ]);

    testWidgets('shows an empty message for no cells', (tester) async {
      await tester.pumpWidget(
        _host(const HourlySalesHeatmap(heatmap: HourlyHeatmap.empty)),
      );

      expect(find.text('Belum ada transaksi pada periode ini'), findsOneWidget);
    });

    testWidgets('renders all seven weekday rows', (tester) async {
      await tester.pumpWidget(_host(const HourlySalesHeatmap(heatmap: populated)));

      for (final label in kWeekdayLabelsShort) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('surfaces the peak hour when nothing is selected',
        (tester) async {
      await tester.pumpWidget(_host(const HourlySalesHeatmap(heatmap: populated)));

      expect(
        find.textContaining('Jam tersibuk: Jumat, 09:00'),
        findsOneWidget,
      );
    });

    testWidgets('shows the intensity legend', (tester) async {
      await tester.pumpWidget(_host(const HourlySalesHeatmap(heatmap: populated)));

      expect(find.text('Sepi'), findsOneWidget);
      expect(find.text('Ramai'), findsOneWidget);
    });
  });

  group('DayOfWeekBarChart', () {
    testWidgets('shows an empty message when no day has revenue',
        (tester) async {
      await tester.pumpWidget(
        _host(const DayOfWeekBarChart(heatmap: HourlyHeatmap.empty)),
      );

      expect(find.text('Tidak ada data'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('renders a chart when at least one day has revenue',
        (tester) async {
      await tester.pumpWidget(_host(const DayOfWeekBarChart(
        heatmap: HourlyHeatmap([
          HeatmapCell(
            dayOfWeek: 3,
            hourOfDay: 10,
            transactionCount: 2,
            revenue: 90000,
          ),
        ]),
      )));

      expect(find.byType(BarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PeakHoursCard', () {
    testWidgets('explains itself when there is no data', (tester) async {
      await tester.pumpWidget(
        _host(const PeakHoursCard(heatmap: HourlyHeatmap.empty)),
      );

      expect(
        find.text('Belum cukup data untuk menganalisis jam sibuk'),
        findsOneWidget,
      );
    });

    testWidgets('ranks the top hours and names the busiest day',
        (tester) async {
      await tester.pumpWidget(_host(const PeakHoursCard(
        heatmap: HourlyHeatmap([
          HeatmapCell(
            dayOfWeek: 5,
            hourOfDay: 14,
            transactionCount: 4,
            revenue: 268500,
          ),
          HeatmapCell(
            dayOfWeek: 1,
            hourOfDay: 9,
            transactionCount: 2,
            revenue: 80000,
          ),
        ]),
      )));

      // Hour buckets are shown as ranges, not instants.
      expect(find.text('14:00 - 15:00'), findsOneWidget);
      expect(find.text('09:00 - 10:00'), findsOneWidget);
      expect(find.text('Hari Teramai'), findsOneWidget);
      expect(find.text('Jumat'), findsOneWidget);
    });
  });

  group('PeriodComparisonCard', () {
    testWidgets('shows a percentage change against a real baseline',
        (tester) async {
      await tester.pumpWidget(_host(PeriodComparisonCard(
        comparison: PeriodComparison(
          current: _summary(150000),
          previous: _summary(100000),
        ),
      )));

      expect(find.text('50.0%'), findsWidgets);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);
    });

    testWidgets('shows "Baru" instead of an infinite percentage',
        (tester) async {
      // Growth from a zero baseline is undefined, not infinite.
      await tester.pumpWidget(_host(PeriodComparisonCard(
        comparison: PeriodComparison(
          current: _summary(150000),
          previous: _summary(0, txns: 0),
        ),
      )));

      expect(find.text('Baru'), findsWidgets);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(
        find.text('Tidak ada transaksi pada periode sebelumnya'),
        findsOneWidget,
      );
    });

    testWidgets('marks a decline with a downward arrow', (tester) async {
      await tester.pumpWidget(_host(PeriodComparisonCard(
        comparison: PeriodComparison(
          current: _summary(75000),
          previous: _summary(100000),
        ),
      )));

      expect(find.byIcon(Icons.arrow_downward_rounded), findsWidgets);
      expect(find.text('25.0%'), findsWidgets);
    });
  });
}
