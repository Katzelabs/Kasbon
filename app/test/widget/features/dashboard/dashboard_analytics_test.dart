import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:kasbon_pos/features/dashboard/presentation/providers/dashboard_analytics_provider.dart';
import 'package:kasbon_pos/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:kasbon_pos/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:kasbon_pos/features/dashboard/presentation/widgets/dashboard_analytics_section.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/distribution_pie_chart.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/sales_trend_line_chart.dart';

import '../../../helpers/responsive_helpers.dart';
import 'dashboard_fixtures.dart';

/// The analytics band: a week of sales under the cards that describe today.
///
/// The band exists because everything above it describes a single instant, so a
/// shop could not tell a bad Tuesday from a Tuesday that is always quiet. These
/// tests pin the two things that make it useful rather than decorative - that it
/// is present at every tier, and that it says so when it has nothing to show
/// instead of drawing a flat line along the axis and calling it a chart.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  const summary = DashboardSummary(
    todaySales: 250000,
    todayProfit: 90000,
    transactionCount: 12,
    yesterdaySales: 200000,
    yesterdayProfit: 70000,
    lowStockCount: 3,
  );

  List<Override> overrides({
    List<Override> analytics = const [],
  }) =>
      [
        dashboardSummaryProvider.overrideWith((ref) async => summary),
        ...(analytics.isEmpty ? dashboardAnalyticsOverrides() : analytics),
      ];

  Future<void> pumpDashboard(
    WidgetTester tester,
    double width, {
    List<Override> analytics = const [],
  }) {
    return pumpScreenAtWidth(
      tester,
      width,
      const DashboardScreen(),
      providerOverrides: overrides(analytics: analytics),
    );
  }

  group('presence', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets(
        'shows the trend and the top sellers at ${ResponsiveWidths.label(width)}',
        (tester) async {
          await pumpDashboard(tester, width);

          // The header, not the section: at `large` the screen composes the
          // cards into its own two-column layout, so `DashboardAnalyticsSection`
          // is deliberately absent there. The header and the cards are the
          // contract that holds at every tier.
          expect(find.byType(DashboardAnalyticsHeader), findsOneWidget);
          expect(
              find.text('Analitik $dashboardTrendDays Hari'), findsOneWidget);

          expect(find.text('Tren Penjualan'), findsOneWidget);
          expect(find.byType(SalesTrendLineChart), findsOneWidget);

          expect(find.text('Produk Terlaris'), findsOneWidget);
        },
      );
    }

    testWidgets('names the period the band covers', (tester) async {
      await pumpDashboard(tester, ResponsiveWidths.expanded);

      // The cards above are all labelled "Hari Ini". Without the range spelled
      // out, the band reads as the same period disagreeing with them.
      final expected =
          DashboardAnalyticsWindow.trailingDays(dashboardTrendDays).label;
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('lists five top sellers in rank order in a narrow column',
        (tester) async {
      await pumpDashboard(tester, ResponsiveWidths.expanded);

      final shown =
          sampleTopProducts.take(DashboardTopProductsCard.defaultMaxRows);
      for (final product in shown) {
        expect(find.text(product.productName), findsOneWidget);
      }

      // The rest are fetched but not rendered here - the card is one column of
      // a two-up row and a longer list would set the height of both.
      for (final product
          in sampleTopProducts.skip(DashboardTopProductsCard.defaultMaxRows)) {
        expect(find.text(product.productName), findsNothing);
      }

      // Ranked by revenue, which is the order the fixture is in - the highest
      // earner first, not the highest unit count.
      final first = tester.getTopLeft(find.text(shown.first.productName));
      final last = tester.getTopLeft(find.text(shown.last.productName));
      expect(first.dy, lessThan(last.dy));
    });

    testWidgets('shows more sellers on a desktop window', (tester) async {
      await pumpDashboard(tester, ResponsiveWidths.large);

      // Wider genuinely shows more here: the card is ~900dp across in the
      // desktop layout, where five rows leave it two thirds empty.
      final shown =
          sampleTopProducts.take(DashboardTopProductsCard.maxRowsWide);
      expect(
          shown.length, greaterThan(DashboardTopProductsCard.defaultMaxRows));

      for (final product in shown) {
        expect(find.text(product.productName), findsOneWidget);
      }
    });
  });

  group('the payment mix is an addition at the wider tiers', () {
    testWidgets('is not built on a phone', (tester) async {
      // A phone still carries the category menu below the band, and a third
      // chart above it makes the screen a scroll longer for the tier with the
      // least patience for one.
      await pumpDashboard(tester, ResponsiveWidths.compact);

      expect(find.text('Metode Bayar'), findsNothing);
      expect(find.byType(DistributionPieChart), findsNothing);
    });

    for (final width in [
      ResponsiveWidths.medium,
      ResponsiveWidths.expanded,
      ResponsiveWidths.large,
    ]) {
      testWidgets(
        'is built at ${ResponsiveWidths.label(width)}',
        (tester) async {
          await pumpDashboard(tester, width);

          expect(find.text('Metode Bayar'), findsOneWidget);
          expect(find.byType(DistributionPieChart), findsOneWidget);

          // The reason the block earns its place: a strong revenue week that is
          // a third hutang is not a strong week.
          expect(
            find.textContaining('Hutang belum lunas'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('takes the room the category menu gave up at medium',
        (tester) async {
      // The two changes are a pair. `medium` is the first tier with a rail, so
      // the menu goes; the payment mix is what moved into the space. If the menu
      // ever comes back at this tier, this is the test that should start
      // failing rather than the band silently getting a scroll longer.
      await pumpDashboard(tester, ResponsiveWidths.medium);

      expect(find.text('Menu Kategori'), findsNothing);
      expect(find.text('Metode Bayar'), findsOneWidget);
    });

    testWidgets('never drops a block as the window gets wider', (tester) async {
      Map<String, int> census() => {
            'trend': find.text('Tren Penjualan').evaluate().length,
            'top': find.text('Produk Terlaris').evaluate().length,
            'payment': find.text('Metode Bayar').evaluate().length,
          };

      await pumpDashboard(tester, ResponsiveWidths.compact);

      var previous = census();
      var previousWidth = ResponsiveWidths.compact;

      for (final width in ResponsiveWidths.all.skip(1)) {
        setViewWidth(tester, width);
        await tester.pumpAndSettle();

        final current = census();
        for (final block in previous.keys) {
          expect(
            current[block],
            greaterThanOrEqualTo(previous[block]!),
            reason: '$block is shown ${previous[block]} times at '
                '$previousWidth but ${current[block]} times at $width',
          );
        }

        previous = current;
        previousWidth = width;
      }
    });
  });

  group('states', () {
    testWidgets('says so when the week had no sales', (tester) async {
      // A gap-filled series is never *empty* for a non-empty window, so "no
      // sales" arrives as an all-zero series. Drawing that as a chart would put
      // a flat line along the axis and imply a reading that was never taken.
      await pumpDashboard(
        tester,
        ResponsiveWidths.expanded,
        analytics: dashboardAnalyticsOverrides(
          trend: emptyTrend(),
          topProducts: const [],
        ),
      );

      expect(find.byType(SalesTrendLineChart), findsNothing);
      expect(
        find.text('Belum ada penjualan pada periode ini'),
        findsOneWidget,
      );
      expect(find.text('Belum ada produk terjual'), findsOneWidget);
    });

    testWidgets('offers a retry when a block fails', (tester) async {
      await pumpDashboard(
        tester,
        ResponsiveWidths.expanded,
        analytics: [
          dashboardSalesTrendProvider.overrideWith(
            (ref) async => throw Exception('gagal'),
          ),
          dashboardTopProductsProvider.overrideWith(
            (ref) async => sampleTopProducts,
          ),
          dashboardPaymentMixProvider.overrideWith(
            (ref) async => samplePaymentMix,
          ),
        ],
      );

      expect(find.text('Gagal memuat data'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // One block failing must not take the others with it.
      expect(find.text('Produk Terlaris'), findsOneWidget);
      expect(find.text('Metode Bayar'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets(
        'lays out without overflow at ${ResponsiveWidths.label(width)}',
        (tester) async {
          await pumpDashboard(tester, width);

          // A RenderFlex overflow is reported to the error handler rather than
          // thrown, so a three-across band that does not fit would otherwise
          // pass every assertion above.
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('sits above the category menu on a phone', (tester) async {
      await pumpDashboard(tester, ResponsiveWidths.compact);

      // Compact is the only tier that still has the menu. Even there the band
      // comes first: the menu is a second copy of navigation the shell already
      // provides, a week of sales is not. This pins the ordering, which is
      // otherwise the kind of thing a later edit reverses without noticing.
      final band = tester.getTopLeft(
        find.text('Analitik $dashboardTrendDays Hari'),
      );
      final menu = tester.getTopLeft(find.text('Menu Kategori'));
      expect(band.dy, lessThan(menu.dy));
    });

    testWidgets('splits into a week column and a today column at large',
        (tester) async {
      await pumpDashboard(tester, ResponsiveWidths.large);

      final analytics =
          tester.getTopLeft(find.text('Analitik $dashboardTrendDays Hari'));
      final today = tester.getTopLeft(find.text('Hari Ini'));

      // Side by side, not stacked - the whole point of the desktop layout.
      expect(today.dx, greaterThan(analytics.dx));

      // And level with each other. The sidebar header exists partly to keep
      // them so; without it the sidebar started 46dp low, which reads as a
      // layout slip rather than a choice.
      expect(today.dy, equals(analytics.dy));

      // The analytics column is the wider of the two: the trend chart is the
      // thing everyone came to look at, so it gets 2/3 rather than an even
      // split.
      final trendWidth = tester.getSize(find.byType(SalesTrendLineChart)).width;
      final donutWidth =
          tester.getSize(find.byType(DistributionPieChart)).width;
      expect(trendWidth, greaterThan(donutWidth * 1.5));
    });

    testWidgets('labels the payment mix with its own period in the sidebar',
        (tester) async {
      await pumpDashboard(tester, ResponsiveWidths.large);

      // At `large` this card sits under a "Hari Ini" heading beside a summary
      // card and a stock alert, all of which describe today. It covers a week,
      // so it has to say so or it reads as a same-day figure.
      final window =
          DashboardAnalyticsWindow.trailingDays(dashboardTrendDays).label;
      expect(find.text(window), findsNWidgets(2));
    });
  });
}
