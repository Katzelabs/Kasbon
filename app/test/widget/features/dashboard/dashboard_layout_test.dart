import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:kasbon_pos/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:kasbon_pos/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:kasbon_pos/features/dashboard/presentation/widgets/low_stock_alert.dart';
import 'package:kasbon_pos/features/dashboard/presentation/widgets/sales_summary_card.dart';

import '../../../helpers/responsive_helpers.dart';

/// The dashboard's rule is that a wider window never shows *less*.
///
/// It used to break that badly: the "tablet" build dropped the welcome banner
/// and replaced the whole sales summary card with four compact tiles, so
/// dragging a window from 890dp to 910dp removed content. These tests pin the
/// direction of the relationship rather than the pixel layout - each tier must
/// show everything the tier below it showed.
void main() {
  const summary = DashboardSummary(
    todaySales: 250000,
    todayProfit: 90000,
    transactionCount: 12,
    yesterdaySales: 200000,
    yesterdayProfit: 70000,
    lowStockCount: 3,
  );

  const noLowStock = DashboardSummary(
    todaySales: 250000,
    todayProfit: 90000,
    transactionCount: 12,
    yesterdaySales: 200000,
    yesterdayProfit: 70000,
    lowStockCount: 0,
  );

  List<Override> overridesFor(DashboardSummary value) => [
        dashboardSummaryProvider.overrideWith((ref) async => value),
      ];

  for (final width in ResponsiveWidths.all) {
    testWidgets(
      'shows the banner, the summary and the menu at ${ResponsiveWidths.label(width)}',
      (tester) async {
        await pumpScreenAtWidth(
          tester,
          width,
          const DashboardScreen(),
          providerOverrides: overridesFor(summary),
        );

        // The banner was the most visible casualty of the old fork - present
        // on a phone, gone on a tablet.
        expect(find.text('Selamat Datang!'), findsOneWidget);

        // As was the summary card. The four stat tiles were a *replacement*
        // for it, not an addition, so the headline figure and the profit and
        // transaction breakdown all disappeared at 900dp.
        expect(find.byType(SalesSummaryCard), findsOneWidget);

        expect(find.text('Menu Kategori'), findsOneWidget);
      },
    );
  }

  // The acceptance criterion, stated directly: count the same four sections at
  // every tier and assert the counts never go down as the window grows.
  testWidgets('never shows less as the window gets wider', (tester) async {
    Map<String, int> census() => {
          'banner': find.text('Selamat Datang!').evaluate().length,
          'summary': find.byType(SalesSummaryCard).evaluate().length,
          'alert': find.byType(LowStockAlert).evaluate().length,
          'menu': find.text('Menu Kategori').evaluate().length,
        };

    // One tree, resized - a real window drag rather than four separate pumps,
    // which is also the case the old fork got wrong.
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const DashboardScreen(),
      providerOverrides: overridesFor(summary),
    );

    var previous = census();
    var previousWidth = ResponsiveWidths.compact;

    for (final width in ResponsiveWidths.all.skip(1)) {
      setViewWidth(tester, width);
      await tester.pumpAndSettle();

      final current = census();
      for (final section in previous.keys) {
        expect(
          current[section],
          greaterThanOrEqualTo(previous[section]!),
          reason: '$section is shown ${previous[section]} times at '
              '$previousWidth but ${current[section]} times at $width',
        );
      }

      previous = current;
      previousWidth = width;
    }
  });

  testWidgets('adds the stats row at expanded rather than swapping for it',
      (tester) async {
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.expanded,
      const DashboardScreen(),
      providerOverrides: overridesFor(summary),
    );

    // The four tiles appear...
    expect(find.text('Penjualan Hari Ini'), findsWidgets);
    expect(find.text('Laba Hari Ini'), findsOneWidget);
    expect(find.text('Transaksi Hari Ini'), findsOneWidget);
    expect(find.text('Stok Rendah'), findsOneWidget);
    // ...alongside the card they used to replace.
    expect(find.byType(SalesSummaryCard), findsOneWidget);
  });

  testWidgets('does not show the stats row below expanded', (tester) async {
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.medium,
      const DashboardScreen(),
      providerOverrides: overridesFor(summary),
    );

    // These four labels belong only to the tiles; the summary card's own
    // header reads "Penjualan Hari Ini" too, so the other three are the ones
    // that identify the row.
    expect(find.text('Laba Hari Ini'), findsNothing);
    expect(find.text('Transaksi Hari Ini'), findsNothing);
    expect(find.text('Stok Rendah'), findsNothing);
  });

  for (final width in ResponsiveWidths.all) {
    testWidgets(
      'shows the low-stock alert when stock is low at ${ResponsiveWidths.label(width)}',
      (tester) async {
        await pumpScreenAtWidth(
          tester,
          width,
          const DashboardScreen(),
          providerOverrides: overridesFor(summary),
        );

        expect(find.byType(LowStockAlert), findsOneWidget);
      },
    );

    testWidgets(
      'hides the low-stock alert when nothing is low at ${ResponsiveWidths.label(width)}',
      (tester) async {
        await pumpScreenAtWidth(
          tester,
          width,
          const DashboardScreen(),
          providerOverrides: overridesFor(noLowStock),
        );

        // The expanded and large layouts give the alert its own column; with
        // nothing low on stock that column has to collapse rather than render
        // an empty strip beside the summary.
        expect(find.byType(LowStockAlert), findsNothing);
      },
    );
  }

  for (final width in ResponsiveWidths.all) {
    testWidgets(
      'lays out without overflow at ${ResponsiveWidths.label(width)}',
      (tester) async {
        await pumpScreenAtWidth(
          tester,
          width,
          const DashboardScreen(),
          providerOverrides: overridesFor(summary),
        );

        // A RenderFlex overflow is reported through the error handler rather
        // than by throwing, so an unguarded Row in one of the wide layouts
        // would otherwise pass every assertion above.
        expect(tester.takeException(), isNull);
      },
    );
  }
}
