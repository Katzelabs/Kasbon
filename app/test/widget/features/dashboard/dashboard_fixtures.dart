import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasbon_pos/features/dashboard/presentation/providers/dashboard_analytics_provider.dart';
import 'package:kasbon_pos/features/reports/domain/entities/payment_slice.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_report.dart';
import 'package:kasbon_pos/features/reports/domain/entities/report_filter.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';

/// Fixtures for the dashboard's analytics band.
///
/// The band's three providers each reach into `getIt` for a report use case, so
/// a test that pumps `DashboardScreen` without overriding them renders three
/// error cards instead of the content it is asserting on. Every dashboard test
/// therefore wants [dashboardAnalyticsOverrides], which is why they live in one
/// place rather than being restated per file.

/// A rising seven-day series, gap-filled the way the provider returns it.
///
/// Built from [DashboardAnalyticsWindow] rather than from hard-coded dates so
/// the points always land inside the window the widget computes for itself -
/// otherwise the fixture silently ages out of range.
List<SalesTrendPoint> sampleTrend({int days = dashboardTrendDays}) {
  final window = DashboardAnalyticsWindow.trailingDays(days);
  return [
    for (var i = 0; i < days; i++)
      SalesTrendPoint(
        bucketStart: DateTime(
          window.from.year,
          window.from.month,
          window.from.day + i,
        ),
        granularity: TrendGranularity.day,
        revenue: 100000 + i * 25000,
        profit: 30000 + i * 8000,
        transactionCount: 4 + i,
        itemsSold: 9 + i * 2,
      ),
  ];
}

/// A seven-day series where the shop sold nothing, which is what a new install
/// and a closed week both look like.
List<SalesTrendPoint> emptyTrend({int days = dashboardTrendDays}) {
  final window = DashboardAnalyticsWindow.trailingDays(days);
  return [
    for (var i = 0; i < days; i++)
      SalesTrendPoint.empty(
        DateTime(window.from.year, window.from.month, window.from.day + i),
        TrendGranularity.day,
      ),
  ];
}

const List<ProductReport> sampleTopProducts = [
  ProductReport(
    productId: 'p1',
    productName: 'Kopi Susu Gula Aren',
    quantitySold: 48,
    totalRevenue: 720000,
    totalProfit: 264000,
  ),
  ProductReport(
    productId: 'p2',
    productName: 'Teh Manis Dingin',
    quantitySold: 61,
    totalRevenue: 427000,
    totalProfit: 195000,
  ),
  ProductReport(
    productId: 'p3',
    productName: 'Nasi Goreng Spesial',
    quantitySold: 17,
    totalRevenue: 391000,
    totalProfit: 120000,
  ),
  ProductReport(
    productId: 'p4',
    productName: 'Roti Bakar Cokelat',
    quantitySold: 22,
    totalRevenue: 264000,
    totalProfit: 99000,
  ),
  ProductReport(
    productId: 'p5',
    productName: 'Air Mineral 600ml',
    quantitySold: 74,
    totalRevenue: 222000,
    totalProfit: 66000,
  ),
  // Rows 6-8 are rendered only by the desktop layout, which shows
  // [DashboardTopProductsCard.maxRowsWide]. They are here so a test at `large`
  // exercises the longer list rather than silently falling back to five.
  ProductReport(
    productId: 'p6',
    productName: 'Es Jeruk Peras',
    quantitySold: 29,
    totalRevenue: 203000,
    totalProfit: 87000,
  ),
  ProductReport(
    productId: 'p7',
    productName: 'Mie Goreng Telur',
    quantitySold: 14,
    totalRevenue: 182000,
    totalProfit: 63000,
  ),
  ProductReport(
    productId: 'p8',
    productName: 'Kerupuk Kemasan',
    quantitySold: 41,
    totalRevenue: 123000,
    totalProfit: 49000,
  ),
];

/// A payment mix that includes an unpaid debt slice, so the hutang note renders.
const List<PaymentSlice> samplePaymentMix = [
  PaymentSlice(
    method: PaymentMethod.cash,
    rawMethod: 'cash',
    transactionCount: 34,
    total: 1240000,
    unpaidTotal: 0,
  ),
  PaymentSlice(
    method: PaymentMethod.qris,
    rawMethod: 'qris',
    transactionCount: 12,
    total: 480000,
    unpaidTotal: 0,
  ),
  PaymentSlice(
    method: PaymentMethod.debt,
    rawMethod: 'debt',
    transactionCount: 5,
    total: 210000,
    unpaidTotal: 150000,
  ),
];

/// Overrides for the three analytics providers, defaulting to a shop with a
/// healthy week.
List<Override> dashboardAnalyticsOverrides({
  List<SalesTrendPoint>? trend,
  List<ProductReport>? topProducts,
  List<PaymentSlice>? paymentMix,
}) {
  return [
    dashboardSalesTrendProvider.overrideWith(
      (ref) async => trend ?? sampleTrend(),
    ),
    dashboardTopProductsProvider.overrideWith(
      (ref) async => topProducts ?? sampleTopProducts,
    ),
    dashboardPaymentMixProvider.overrideWith(
      (ref) async => paymentMix ?? samplePaymentMix,
    ),
  ];
}
