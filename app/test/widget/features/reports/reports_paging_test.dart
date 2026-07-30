import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/reports/domain/entities/customer_analytics.dart';
import 'package:kasbon_pos/features/reports/domain/entities/daily_sales.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_movement.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_report.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/analytics_provider.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/report_provider.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/customer_report_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/inventory_movement_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/product_report_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/customer_analytics_tile.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/daily_sales_list.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/product_movement_tile.dart';

import '../../../helpers/responsive_helpers.dart';

/// What these reports do when a shop has more rows than the screen asked for.
///
/// Two separate failures live here and they want different fixes, so they are
/// tested separately:
///
///  * The **silent cut** - the product report fetched 100 rows and said
///    nothing, so a shop with 300 products read a total that did not reconcile
///    and had no way to see why. Fixed by naming the count and offering more.
///  * The **eager build** - the inventory report built every one of the 500
///    rows its RPC can return, and the daily breakdown built one tile per day
///    in the range. Fixed by capping what is rendered, which is not the same
///    thing as capping what is fetched.

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

List<ProductReport> _products(int count) => [
      for (var i = 1; i <= count; i++)
        ProductReport(
          productId: 'p$i',
          productName: 'Produk $i',
          quantitySold: count - i + 1,
          totalRevenue: 10000.0 * (count - i + 1),
          totalProfit: 3000.0 * (count - i + 1),
        ),
    ];

List<CustomerAnalytics> _customers(int count) => [
      for (var i = 1; i <= count; i++)
        CustomerAnalytics(
          customerName: 'Pelanggan $i',
          transactionCount: 3,
          totalSpent: 100000.0 * (count - i + 1),
          averageTransaction: 50000,
          lastTransactionAt: DateTime(2026, 7, 20),
          outstandingDebt: 0,
          totalProfit: 20000,
          lifetimeTransactionCount: 5,
          lifetimeSpent: 500000,
          firstTransactionAt: DateTime(2026),
        ),
    ];

List<ProductMovement> _movements(int count) => [
      for (var i = 1; i <= count; i++)
        ProductMovement(
          id: 'm$i',
          name: 'Barang $i',
          sku: 'SKU-${i.toString().padLeft(5, '0')}',
          currentStock: 10,
          costPrice: 5000,
          stockValue: 50000,
          quantitySold: count - i + 1,
          totalRevenue: 20000.0 * (count - i + 1),
          totalCogs: 12000.0 * (count - i + 1),
          totalProfit: 8000.0 * (count - i + 1),
          lastSoldAt: DateTime(2026, 7, 20),
          turnoverRatio: 1 + i / 100,
          daysOfSupply: 12,
          isSlowMoving: false,
        ),
    ];

final _categories = [
  Category(
    id: 'c1',
    name: 'Makanan',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

/// Scrolls [finder] into view and taps it.
///
/// The footer sits under everything else on these screens, so at any realistic
/// viewport height it starts off-screen - a bare `tap` would miss.
Future<void> _tapFooter(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ProductReportScreen', () {
    /// Serves `limit` rows out of a catalogue of [total], the way the RPC does.
    List<Override> overrides(int total) => [
          categoriesProvider.overrideWith((ref) async => _categories),
          filteredProductReportProvider.overrideWith((ref) async {
            final limit = ref.watch(productReportLimitProvider);
            return _products(total).take(limit).toList();
          }),
        ];

    testWidgets('names the cut when the catalogue is deeper than a page',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        1100,
        const ProductReportScreen(),
        height: 1400,
        providerOverrides: overrides(250),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menampilkan 100 produk teratas'), findsOneWidget);
      expect(find.text('Muat Lebih Banyak'), findsOneWidget);
    });

    testWidgets('says so plainly when everything already fits', (tester) async {
      await pumpScreenAtWidth(
        tester,
        1100,
        const ProductReportScreen(),
        height: 1400,
        providerOverrides: overrides(12),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menampilkan semua 12 produk'), findsOneWidget);
      expect(find.text('Muat Lebih Banyak'), findsNothing);
    });

    testWidgets('loading more asks the server for a deeper page',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        1100,
        const ProductReportScreen(),
        height: 1400,
        providerOverrides: overrides(250),
      );
      await tester.pumpAndSettle();

      await _tapFooter(tester, find.text('Muat Lebih Banyak'));

      expect(find.text('Menampilkan 200 produk teratas'), findsOneWidget);
    });

    testWidgets('stops offering more once the list comes back short',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        1100,
        const ProductReportScreen(),
        height: 1400,
        providerOverrides: overrides(140),
      );
      await tester.pumpAndSettle();

      await _tapFooter(tester, find.text('Muat Lebih Banyak'));

      // 140 rows against a 200 ceiling: the catalogue ended.
      expect(find.text('Menampilkan semua 140 produk'), findsOneWidget);
      expect(find.text('Muat Lebih Banyak'), findsNothing);
    });
  });

  group('CustomerReportScreen', () {
    List<Override> overrides(int total) => [
          topCustomersProvider.overrideWith((ref) async {
            final limit = ref.watch(customerReportLimitProvider);
            return _customers(total).take(limit).toList();
          }),
        ];

    testWidgets('extends a page at a time', (tester) async {
      await pumpScreenAtWidth(
        tester,
        1100,
        const CustomerReportScreen(),
        height: 1400,
        providerOverrides: overrides(90),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAnalyticsTile), findsNWidgets(20));

      await _tapFooter(tester, find.text('Muat Lebih Banyak'));

      expect(find.byType(CustomerAnalyticsTile), findsNWidgets(40));
    });
  });

  group('InventoryMovementScreen', () {
    List<Override> overrides(int total) => [
          productMovementProvider
              .overrideWith((ref) async => _movements(total)),
        ];

    testWidgets('builds a page of rows, not every row it was handed',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        700,
        const InventoryMovementScreen(),
        height: 1400,
        providerOverrides: overrides(300),
      );
      await tester.pumpAndSettle();

      // The whole 300 arrived; 50 are in the tree. This is the assertion the
      // eager `Column` could never have passed.
      expect(find.byType(ProductMovementTile), findsNWidgets(50));

      await _tapFooter(tester, find.text('Muat Lebih Banyak'));

      expect(find.byType(ProductMovementTile), findsNWidgets(100));
    });

    testWidgets('switching view starts the new list at the top',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        700,
        const InventoryMovementScreen(),
        height: 1400,
        providerOverrides: overrides(300),
      );
      await tester.pumpAndSettle();

      await _tapFooter(tester, find.text('Muat Lebih Banyak'));
      expect(find.byType(ProductMovementTile), findsNWidgets(100));

      await tester.ensureVisible(find.text('Kurang Laku'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kurang Laku'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perputaran'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductMovementTile), findsNWidgets(50));
    });

    testWidgets('distinguishes a full payload from a complete one',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        700,
        const InventoryMovementScreen(),
        height: 1400,
        // Exactly the RPC's own ceiling: the report stopped counting, the shop
        // did not run out of products.
        providerOverrides: overrides(productMovementFetchLimit),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < productMovementFetchLimit ~/ 50 - 1; i++) {
        await _tapFooter(tester, find.text('Muat Lebih Banyak'));
      }

      expect(
        find.text('Menampilkan 500 produk teratas (batas laporan)'),
        findsOneWidget,
      );
    });
  });

  group('DailySalesList', () {
    List<DailySales> days(int count) => [
          for (var i = 1; i <= count; i++)
            DailySales(
              date: DateTime(2026).add(Duration(days: i)),
              revenue: 100000 + i * 1000,
              transactionCount: i,
            ),
        ];

    testWidgets('shows a month of a year, then extends', (tester) async {
      await pumpScreenAtWidth(
        tester,
        700,
        // Scaffold because the footer is an InkWell, which wants a Material
        // ancestor; on the real screen the report Scaffold supplies it.
        Scaffold(
          body: SingleChildScrollView(
            child: DailySalesList(dailySales: days(365), showAll: true),
          ),
        ),
        height: 1400,
      );
      await tester.pumpAndSettle();

      expect(find.text('Muat Lebih Banyak (30/365 hari)'), findsOneWidget);

      await _tapFooter(tester, find.text('Muat Lebih Banyak (30/365 hari)'));

      expect(find.text('Muat Lebih Banyak (60/365 hari)'), findsOneWidget);
    });

    testWidgets('offers nothing to extend when the range is short',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        700,
        Scaffold(
          body: SingleChildScrollView(
            child: DailySalesList(dailySales: days(7), showAll: true),
          ),
        ),
        height: 1400,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Muat Lebih Banyak'), findsNothing);
    });
  });
}
