import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/features/reports/domain/entities/daily_sales.dart';
import 'package:kasbon_pos/features/reports/domain/entities/heatmap_cell.dart';
import 'package:kasbon_pos/features/reports/domain/entities/period_comparison.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_summary.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/day_of_week_bar_chart.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/distribution_pie_chart.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/hourly_sales_heatmap.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/peak_hours_card.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/period_comparison_card.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/sales_bar_chart.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/sales_trend_line_chart.dart';

import '../../../helpers/responsive_helpers.dart';

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
      await tester
          .pumpWidget(_host(const HourlySalesHeatmap(heatmap: populated)));

      for (final label in kWeekdayLabelsShort) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('surfaces the peak hour when nothing is selected',
        (tester) async {
      await tester
          .pumpWidget(_host(const HourlySalesHeatmap(heatmap: populated)));

      expect(
        find.textContaining('Jam tersibuk: Jumat, 09:00'),
        findsOneWidget,
      );
    });

    testWidgets('shows the intensity legend', (tester) async {
      await tester
          .pumpWidget(_host(const HourlySalesHeatmap(heatmap: populated)));

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

  // Every test above pins a chart at a single fixed 400dp width. These pin the
  // other axis: that each chart survives the full 375-1600dp range it will be
  // asked to render across once the responsive overhaul lands.
  //
  // This is a floor, not a ceiling. It catches "throws when wide", not "looks
  // right when wide" - RESP_09b is where these charts get real layout
  // decisions (legend beside the pie, capped bar widths, pane-derived heatmap
  // cells). Until then, this is the regression net for that work.
  group('renders across every breakpoint tier', () {
    const heatmap = HourlyHeatmap([
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
    ]);

    final charts = <String, Widget>{
      'SalesTrendLineChart': SalesTrendLineChart(
        points: [
          for (var day = 1; day <= 31; day++)
            _point(day, (day * 1000).toDouble()),
        ],
      ),
      'DistributionPieChart': const DistributionPieChart(
        slices: [
          PieSliceData(label: 'Makanan', value: 682500, color: Colors.orange),
          PieSliceData(label: 'Minuman', value: 279500, color: Colors.blue),
        ],
      ),
      'HourlySalesHeatmap': const HourlySalesHeatmap(heatmap: heatmap),
      'DayOfWeekBarChart': const DayOfWeekBarChart(heatmap: heatmap),
      'PeakHoursCard': const PeakHoursCard(heatmap: heatmap),
    };

    for (final entry in charts.entries) {
      for (final width in ResponsiveWidths.all) {
        testWidgets(
          '${entry.key} at ${ResponsiveWidths.label(width)}',
          (tester) async {
            await pumpAtWidth(
              tester,
              width,
              SingleChildScrollView(child: entry.value),
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  // RESP_09b. The group above proves the charts do not throw when wide. These
  // pin what they should actually *do* with the width - which is the part a
  // "renders without exception" test will happily let regress.
  group('chart layout scales with the pane', () {
    const heatmap = HourlyHeatmap([
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
    ]);

    const slices = [
      PieSliceData(label: 'Makanan', value: 682500, color: Colors.orange),
      PieSliceData(label: 'Minuman', value: 279500, color: Colors.blue),
    ];

    /// Pumps [child] into a pane [paneWidth] wide inside a [windowWidth]
    /// window - the shape of a dashboard cell, and the case where reading the
    /// window instead of the container goes wrong.
    Future<void> pumpInPane(
      WidgetTester tester, {
      required double windowWidth,
      required double paneWidth,
      required Widget child,
    }) async {
      await pumpAtWidth(
        tester,
        windowWidth,
        SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: paneWidth, child: child),
          ),
        ),
      );
    }

    group('HourlySalesHeatmap', () {
      test('cell size derives from the pane, between its two bounds', () {
        // Too narrow for 24 legible columns: hold the floor and let the grid
        // scroll rather than shrinking cells out of reach of a finger.
        expect(HourlySalesHeatmap.cellSizeFor(375), 26);
        expect(HourlySalesHeatmap.cellSizeFor(460), 26);

        // Enough room: grow to fill it exactly.
        expect(HourlySalesHeatmap.cellSizeFor(34 + 24 * 32), closeTo(32, 0.01));

        // Past the ceiling, stop - a grid of playing cards is not more
        // readable than a grid of tiles.
        expect(HourlySalesHeatmap.cellSizeFor(2560), 44);
      });

      testWidgets('cells size from the pane, not the window', (tester) async {
        // A 460dp cell of a two-column dashboard on a 1600dp window. Reading
        // the window here would give 65dp cells in a 460dp box.
        await pumpInPane(
          tester,
          windowWidth: 1600,
          paneWidth: 460,
          child: const HourlySalesHeatmap(heatmap: heatmap),
        );

        final cells = find.descendant(
          of: find.byType(HourlySalesHeatmap),
          matching: find.byType(GestureDetector),
        );

        expect(cells, findsNWidgets(7 * 24));
        expect(tester.getSize(cells.first).width, 26);
        expect(tester.takeException(), isNull);
      });

      testWidgets('grows its cells when the pane is wide', (tester) async {
        await pumpInPane(
          tester,
          windowWidth: 1600,
          paneWidth: 34 + 24 * 36,
          child: const HourlySalesHeatmap(heatmap: heatmap),
        );

        final cells = find.descendant(
          of: find.byType(HourlySalesHeatmap),
          matching: find.byType(GestureDetector),
        );

        expect(tester.getSize(cells.first).width, closeTo(36, 0.01));
      });
    });

    group('DistributionPieChart', () {
      testWidgets('stacks the legend under the donut on a phone',
          (tester) async {
        await pumpInPane(
          tester,
          windowWidth: 375,
          paneWidth: 343,
          child: const DistributionPieChart(slices: slices),
        );

        final donut = tester.getRect(find.byType(PieChart));
        final legendEntry = tester.getRect(find.text('Makanan'));

        expect(legendEntry.top, greaterThan(donut.bottom - 1));
      });

      testWidgets('puts the legend beside the donut when there is room',
          (tester) async {
        await pumpInPane(
          tester,
          windowWidth: 1600,
          paneWidth: 900,
          child: const DistributionPieChart(slices: slices),
        );

        final donut = tester.getRect(find.byType(PieChart));
        final legendEntry = tester.getRect(find.text('Makanan'));

        expect(legendEntry.left, greaterThan(donut.right));
        // And the donut stops growing rather than filling the row.
        expect(donut.width, lessThanOrEqualTo(260));
      });

      testWidgets('keeps stacking inside a narrow dashboard cell',
          (tester) async {
        // Expanded window, but the chart only has a 380dp cell of it - not
        // enough for a donut and a legend column side by side.
        await pumpInPane(
          tester,
          windowWidth: 1600,
          paneWidth: 380,
          child: const DistributionPieChart(slices: slices),
        );

        final donut = tester.getRect(find.byType(PieChart));
        final legendEntry = tester.getRect(find.text('Makanan'));

        expect(legendEntry.top, greaterThan(donut.bottom - 1));
      });
    });

    group('SalesTrendLineChart', () {
      /// Labels the chart drew. Skipped buckets render a `SizedBox`, so the
      /// `Text` count is the visible label count.
      int labelCount(WidgetTester tester) => tester
          .widgetList(find.descendant(
            of: find.byType(LineChart),
            matching: find.byType(Text),
          ))
          .length;

      testWidgets('names more buckets when it has more room', (tester) async {
        final points = [
          for (var day = 1; day <= 31; day++)
            _point(day, (day * 1000).toDouble()),
        ];

        await pumpInPane(
          tester,
          windowWidth: 375,
          paneWidth: 343,
          child: SalesTrendLineChart(points: points),
        );
        final narrow = labelCount(tester);

        await pumpInPane(
          tester,
          windowWidth: 1600,
          paneWidth: 1100,
          child: SalesTrendLineChart(points: points),
        );
        final wide = labelCount(tester);

        expect(wide, greaterThan(narrow));
      });
    });

    group('bar charts stop growing', () {
      testWidgets('the weekday chart is capped well short of the window',
          (tester) async {
        await pumpInPane(
          tester,
          windowWidth: 2560,
          paneWidth: 2560,
          child: const DayOfWeekBarChart(heatmap: heatmap),
        );

        expect(
          tester.getSize(find.byType(BarChart)).width,
          lessThanOrEqualTo(640),
        );
      });

      testWidgets('the daily chart is capped, and its bars with it',
          (tester) async {
        await pumpInPane(
          tester,
          windowWidth: 2560,
          paneWidth: 2560,
          child: SalesBarChart(
            dailySales: [
              for (var day = 1; day <= 7; day++)
                DailySales(
                  date: DateTime(2026, 7, day),
                  revenue: day * 10000,
                  transactionCount: day,
                ),
            ],
          ),
        );

        expect(
          tester.getSize(find.byType(BarChart)).width,
          lessThanOrEqualTo(960),
        );

        final rod = tester
            .widget<BarChart>(find.byType(BarChart))
            .data
            .barGroups
            .first
            .barRods
            .first;

        // Seven bars across 900dp is 128dp a slot; without the cap each bar
        // would be nearly 80dp wide.
        expect(rod.width, lessThanOrEqualTo(28));
      });
    });
  });
}
