import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/reports/domain/entities/category_slice.dart';
import 'package:kasbon_pos/features/reports/domain/entities/customer_analytics.dart';
import 'package:kasbon_pos/features/reports/domain/entities/daily_sales.dart';
import 'package:kasbon_pos/features/reports/domain/entities/heatmap_cell.dart';
import 'package:kasbon_pos/features/reports/domain/entities/payment_slice.dart';
import 'package:kasbon_pos/features/reports/domain/entities/period_comparison.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_movement.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_profitability.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_report.dart';
import 'package:kasbon_pos/features/reports/domain/entities/profit_summary.dart';
import 'package:kasbon_pos/features/reports/domain/entities/report_filter.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_summary.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/analytics_provider.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/profit_report_provider.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/report_provider.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/analytics_report_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/customer_report_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/inventory_movement_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/product_report_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/profit_report_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/reports_hub_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/screens/sales_report_screen.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/profit_summary_card.dart';
import 'package:kasbon_pos/features/reports/presentation/widgets/report_layout.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/responsive_helpers.dart';

/// RESP_09b: the seven report screens, at every width they will be asked to
/// render at.
///
/// The feature had exactly seven width-dependent decisions before this, all of
/// them bottom padding - so "does it render at 2560" was genuinely unknown for
/// every screen here. The first group answers that; the rest pin the specific
/// arrangements each screen is supposed to reach, because a screen that merely
/// does not throw at 2560 is not the same as one that uses it.

/// The five widths the ticket calls for: the four tier representatives plus an
/// ultrawide desktop, which is where an unclamped layout stops being merely
/// wide and starts being unreadable.
const _widths = <double>[375, 700, 1100, 1600, 2560];

String _label(double width) => switch (width) {
      2560 => 'ultrawide(2560)',
      _ => ResponsiveWidths.label(width),
    };

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _summary = SalesSummary(
  totalRevenue: 4250000,
  totalProfit: 1120000,
  transactionCount: 48,
  itemsSold: 132,
  periodStart: DateTime(2026, 7),
  periodEnd: DateTime(2026, 8),
);

final _dailySales = [
  for (var day = 1; day <= 14; day++)
    DailySales(
      date: DateTime(2026, 7, day),
      revenue: 100000 + day * 12500,
      transactionCount: day,
    ),
];

const _products = [
  ProductReport(
    productId: 'p1',
    productName: 'Nasi Goreng Spesial',
    quantitySold: 42,
    totalRevenue: 1050000,
    totalProfit: 420000,
  ),
  ProductReport(
    productId: 'p2',
    productName: 'Es Teh Manis',
    quantitySold: 88,
    totalRevenue: 440000,
    totalProfit: 264000,
  ),
  ProductReport(
    productId: 'p3',
    productName: 'Ayam Bakar',
    quantitySold: 21,
    totalRevenue: 630000,
    totalProfit: 189000,
  ),
];

final _profit = ProfitSummary(
  totalProfit: 1120000,
  totalSales: 4250000,
  profitMargin: 26.4,
  transactionCount: 48,
  periodStart: DateTime(2026, 7),
  periodEnd: DateTime(2026, 8),
);

const _profitable = [
  ProductProfitability(
    productId: 'p1',
    productName: 'Nasi Goreng Spesial',
    totalProfit: 420000,
    totalSold: 42,
    averageMargin: 40,
  ),
  ProductProfitability(
    productId: 'p2',
    productName: 'Es Teh Manis',
    totalProfit: 264000,
    totalSold: 88,
    averageMargin: 60,
  ),
];

final _trend = [
  for (var day = 1; day <= 21; day++)
    SalesTrendPoint(
      bucketStart: DateTime(2026, 7, day),
      granularity: TrendGranularity.day,
      revenue: 100000 + day * 9000,
      profit: 25000 + day * 2000,
      transactionCount: 3,
      itemsSold: 8,
    ),
];

final _comparison = PeriodComparison(
  current: _summary,
  previous: SalesSummary(
    totalRevenue: 3100000,
    totalProfit: 800000,
    transactionCount: 39,
    itemsSold: 101,
    periodStart: DateTime(2026, 6),
    periodEnd: DateTime(2026, 7),
  ),
);

const _categorySlices = [
  CategorySlice(
    categoryId: 'c1',
    categoryName: 'Makanan',
    categoryColor: '#FF6B35',
    revenue: 2800000,
    profit: 760000,
    quantitySold: 88,
  ),
  CategorySlice(
    categoryId: 'c2',
    categoryName: 'Minuman',
    categoryColor: '#2EC4B6',
    revenue: 1450000,
    profit: 360000,
    quantitySold: 44,
  ),
];

const _paymentSlices = [
  PaymentSlice(
    method: PaymentMethod.cash,
    rawMethod: 'cash',
    transactionCount: 30,
    total: 2600000,
    unpaidTotal: 0,
  ),
  PaymentSlice(
    method: PaymentMethod.debt,
    rawMethod: 'debt',
    transactionCount: 18,
    total: 1650000,
    unpaidTotal: 450000,
  ),
];

const _heatmap = HourlyHeatmap([
  HeatmapCell(dayOfWeek: 1, hourOfDay: 9, transactionCount: 2, revenue: 80000),
  HeatmapCell(
    dayOfWeek: 5,
    hourOfDay: 14,
    transactionCount: 4,
    revenue: 268500,
  ),
]);

final _customers = [
  CustomerAnalytics(
    customerName: 'Bu Siti',
    transactionCount: 9,
    totalSpent: 1250000,
    averageTransaction: 138888,
    lastTransactionAt: DateTime(2026, 7, 26),
    outstandingDebt: 150000,
    totalProfit: 320000,
    lifetimeTransactionCount: 24,
    lifetimeSpent: 4100000,
    firstTransactionAt: DateTime(2026, 1, 8),
  ),
  CustomerAnalytics(
    customerName: 'Pak Budi',
    transactionCount: 6,
    totalSpent: 780000,
    averageTransaction: 130000,
    lastTransactionAt: DateTime(2026, 7, 22),
    outstandingDebt: 0,
    totalProfit: 190000,
    lifetimeTransactionCount: 11,
    lifetimeSpent: 1900000,
    firstTransactionAt: DateTime(2026, 3, 2),
  ),
];

final _movements = [
  ProductMovement(
    id: 'm1',
    name: 'Nasi Goreng Spesial',
    sku: 'SKU-00001',
    currentStock: 12,
    costPrice: 15000,
    stockValue: 180000,
    quantitySold: 42,
    totalRevenue: 1050000,
    totalCogs: 630000,
    totalProfit: 420000,
    lastSoldAt: DateTime(2026, 7, 27),
    turnoverRatio: 3.5,
    daysOfSupply: 8,
    isSlowMoving: false,
  ),
  const ProductMovement(
    id: 'm2',
    name: 'Kerupuk Udang',
    sku: 'SKU-00002',
    currentStock: 60,
    costPrice: 4000,
    stockValue: 240000,
    quantitySold: 0,
    totalRevenue: 0,
    totalCogs: 0,
    totalProfit: 0,
    lastSoldAt: null,
    turnoverRatio: 0,
    daysOfSupply: null,
    isSlowMoving: true,
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

/// Every provider the seven screens read, resolved to fixtures.
///
/// All of them reach a use case through GetIt, which is not registered in a
/// widget test - so a screen test either overrides the lot or tests nothing.
List<Override> _overrides() => [
      salesSummaryProvider.overrideWith((ref) async => _summary),
      dailySalesProvider.overrideWith((ref) async => _dailySales),
      topProductsByQtyProvider.overrideWith((ref) async => _products),
      filteredProductReportProvider.overrideWith((ref) async => _products),
      profitSummaryByDateRangeProvider.overrideWith((ref) async => _profit),
      topProfitableProductsProvider.overrideWith((ref) async => _profitable),
      salesTrendProvider.overrideWith((ref) async => _trend),
      periodComparisonProvider.overrideWith((ref) async => _comparison),
      categoryDistributionProvider.overrideWith((ref) async => _categorySlices),
      paymentDistributionProvider.overrideWith((ref) async => _paymentSlices),
      hourlyHeatmapProvider.overrideWith((ref) async => _heatmap),
      topCustomersProvider.overrideWith((ref) async => _customers),
      productMovementProvider.overrideWith((ref) async => _movements),
      categoriesProvider.overrideWith((ref) async => _categories),
    ];

Future<void> _pumpScreen(
  WidgetTester tester,
  double width,
  Widget screen, {
  double height = 1200,
}) async {
  await pumpScreenAtWidth(
    tester,
    width,
    screen,
    height: height,
    providerOverrides: _overrides(),
  );
}

/// True when the two finders' boxes start on the same row, i.e. the layout put
/// them side by side rather than one under the other.
bool _sameRow(WidgetTester tester, Finder a, Finder b) {
  return (tester.getTopLeft(a).dy - tester.getTopLeft(b).dy).abs() < 1.0;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  final screens = <String, Widget Function()>{
    'ReportsHubScreen': ReportsHubScreen.new,
    'SalesReportScreen': SalesReportScreen.new,
    'ProductReportScreen': ProductReportScreen.new,
    'ProfitReportScreen': ProfitReportScreen.new,
    'AnalyticsReportScreen': AnalyticsReportScreen.new,
    'CustomerReportScreen': CustomerReportScreen.new,
    'InventoryMovementScreen': InventoryMovementScreen.new,
  };

  group('every report screen renders at every width', () {
    for (final entry in screens.entries) {
      for (final width in _widths) {
        testWidgets('${entry.key} at ${_label(width)}', (tester) async {
          await _pumpScreen(tester, width, entry.value());

          expect(find.byType(Scaffold), findsWidgets);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('ReportsHubScreen', () {
    testWidgets('stacks the menu on a phone', (tester) async {
      await _pumpScreen(tester, 375, const ReportsHubScreen());

      expect(
        _sameRow(
          tester,
          find.text('Laporan Penjualan'),
          find.text('Laporan Produk'),
        ),
        isFalse,
      );
    });

    testWidgets('lays the menu out in columns once there is room',
        (tester) async {
      await _pumpScreen(tester, 1100, const ReportsHubScreen());

      expect(
        _sameRow(
          tester,
          find.text('Laporan Penjualan'),
          find.text('Laporan Produk'),
        ),
        isTrue,
      );
    });
  });

  group('SalesReportScreen', () {
    testWidgets('stacks chart above breakdown at expanded', (tester) async {
      await _pumpScreen(tester, 1100, const SalesReportScreen());

      expect(
        _sameRow(
          tester,
          find.text('Grafik Penjualan'),
          find.text('Rincian Harian'),
        ),
        isFalse,
      );
    });

    testWidgets('puts the breakdown beside the chart on a desktop window',
        (tester) async {
      await _pumpScreen(tester, 2560, const SalesReportScreen());

      expect(
        _sameRow(
          tester,
          find.text('Grafik Penjualan'),
          find.text('Rincian Harian'),
        ),
        isTrue,
      );
    });
  });

  group('ProductReportScreen', () {
    testWidgets('shows cards, not a table, below expanded', (tester) async {
      await _pumpScreen(tester, 700, const ProductReportScreen());

      expect(find.byType(ModernDataTable<ProductReport>), findsNothing);
      expect(find.text('Nasi Goreng Spesial'), findsOneWidget);
    });

    testWidgets('switches to a table at expanded and up', (tester) async {
      await _pumpScreen(tester, 1100, const ProductReportScreen());

      expect(find.byType(ModernDataTable<ProductReport>), findsOneWidget);
      // Column headers only a table has.
      expect(find.text('Pendapatan'), findsOneWidget);
      expect(find.text('Margin'), findsOneWidget);
    });
  });

  group('ProfitReportScreen', () {
    testWidgets('puts the top products beside the summary at expanded',
        (tester) async {
      await _pumpScreen(tester, 1100, const ProfitReportScreen());

      expect(
        _sameRow(
          tester,
          find.byType(ProfitSummaryCard),
          find.text('Produk Paling Menguntungkan'),
        ),
        isTrue,
      );
    });

    testWidgets('stacks them on a phone', (tester) async {
      await _pumpScreen(tester, 375, const ProfitReportScreen());

      expect(
        _sameRow(
          tester,
          find.byType(ProfitSummaryCard),
          find.text('Produk Paling Menguntungkan'),
        ),
        isFalse,
      );
    });
  });

  group('AnalyticsReportScreen', () {
    testWidgets('is one column on a phone', (tester) async {
      await _pumpScreen(tester, 375, const AnalyticsReportScreen());

      expect(
        _sameRow(
          tester,
          find.text('Tren Penjualan & Laba'),
          find.text('Distribusi Kategori'),
        ),
        isFalse,
      );
    });

    testWidgets('is a two-column dashboard at expanded', (tester) async {
      await _pumpScreen(tester, 1100, const AnalyticsReportScreen());

      // Round-robin over two columns: trend heads the first, the comparison
      // card the second, and the category chart falls under the trend.
      expect(
        _sameRow(
          tester,
          find.text('Tren Penjualan & Laba'),
          find.text('Distribusi Kategori'),
        ),
        isFalse,
      );
      expect(
        tester.getTopLeft(find.text('Distribusi Kategori')).dx,
        closeTo(tester.getTopLeft(find.text('Tren Penjualan & Laba')).dx, 1),
      );
    });

    testWidgets('is a three-column dashboard on a desktop window',
        (tester) async {
      await _pumpScreen(tester, 1600, const AnalyticsReportScreen());

      // With three columns the category chart moves up beside the trend.
      expect(
        _sameRow(
          tester,
          find.text('Tren Penjualan & Laba'),
          find.text('Distribusi Kategori'),
        ),
        isTrue,
      );
    });

    testWidgets('does not stretch to the full width of an ultrawide window',
        (tester) async {
      await _pumpScreen(tester, 2560, const AnalyticsReportScreen());

      // ContentWidth.wide caps the dashboard at 1440dp; without it every
      // chart would be drawn 2500dp across.
      final content = tester.getSize(find.byType(ReportDashboardGrid));
      expect(content.width, lessThanOrEqualTo(1440));
    });
  });

  group('CustomerReportScreen', () {
    testWidgets('stacks customer tiles on a phone', (tester) async {
      await _pumpScreen(tester, 375, const CustomerReportScreen());

      expect(
        _sameRow(tester, find.text('Bu Siti'), find.text('Pak Budi')),
        isFalse,
      );
    });

    testWidgets('pairs customer tiles at expanded', (tester) async {
      await _pumpScreen(tester, 1100, const CustomerReportScreen());

      expect(
        _sameRow(tester, find.text('Bu Siti'), find.text('Pak Budi')),
        isTrue,
      );
    });
  });

  group('InventoryMovementScreen', () {
    testWidgets('shows tiles below expanded', (tester) async {
      await _pumpScreen(tester, 700, const InventoryMovementScreen());

      expect(find.byType(ModernDataTable<ProductMovement>), findsNothing);
      expect(find.text('Kerupuk Udang'), findsOneWidget);
    });

    testWidgets('switches to a table at expanded and up', (tester) async {
      await _pumpScreen(tester, 1100, const InventoryMovementScreen());

      expect(find.byType(ModernDataTable<ProductMovement>), findsOneWidget);
      expect(find.text('Perputaran'), findsWidgets);
      expect(find.text('Kerupuk Udang'), findsOneWidget);
    });
  });
}
