import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/daily_sales.dart';
import '../../domain/entities/product_report.dart';
import '../../domain/entities/product_report_filter.dart';
import '../../domain/entities/sales_summary.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/get_daily_sales.dart';
import '../../domain/usecases/get_sales_summary.dart';
import '../../domain/usecases/get_top_products.dart';
import 'date_range_provider.dart';
import 'product_report_filter_provider.dart';

/// Provider for sales summary based on selected date range
final salesSummaryProvider =
    FutureProvider.autoDispose<SalesSummary>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final useCase = getIt<GetSalesSummary>();
  final result = await useCase(dateRange.toParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Provider for daily sales data for chart
final dailySalesProvider =
    FutureProvider.autoDispose<List<DailySales>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final useCase = getIt<GetDailySales>();
  final result = await useCase(dateRange.toParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (sales) => sales,
  );
});

/// Provider for top products by quantity
final topProductsByQtyProvider =
    FutureProvider.autoDispose<List<ProductReport>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final useCase = getIt<GetTopProducts>();
  final result = await useCase(TopProductsParams(
    from: dateRange.from,
    to: dateRange.to,
    sortBy: ProductReportSortType.quantity,
    limit: 10,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

/// Provider for top products by revenue
final topProductsByRevenueProvider =
    FutureProvider.autoDispose<List<ProductReport>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final useCase = getIt<GetTopProducts>();
  final result = await useCase(TopProductsParams(
    from: dateRange.from,
    to: dateRange.to,
    sortBy: ProductReportSortType.revenue,
    limit: 10,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

/// Provider for top products by profit
final topProductsByProfitProvider =
    FutureProvider.autoDispose<List<ProductReport>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final useCase = getIt<GetTopProducts>();
  final result = await useCase(TopProductsParams(
    from: dateRange.from,
    to: dateRange.to,
    sortBy: ProductReportSortType.profit,
    limit: 10,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

/// Provider for sorted product report based on selected sort option
final filteredProductReportProvider =
    FutureProvider.autoDispose<List<ProductReport>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final filter = ref.watch(productReportFilterProvider);
  final useCase = getIt<GetTopProducts>();

  // Determine SQL sort type - use quantity for margin sort (handle client-side)
  final sqlSortType = filter.sortOption == ProductReportSortOption.profitMargin
      ? ProductReportSortType.quantity
      : _mapSortOptionToSqlType(filter.sortOption);

  final result = await useCase(TopProductsParams(
    from: dateRange.from,
    to: dateRange.to,
    sortBy: sqlSortType,
    limit: 100,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) {
      // Apply client-side sorting for profit margin
      if (filter.sortOption == ProductReportSortOption.profitMargin) {
        final sorted = List<ProductReport>.from(products);
        sorted.sort((a, b) => b.profitMargin.compareTo(a.profitMargin));
        return sorted;
      }
      return products;
    },
  );
});

/// Map filter sort option to SQL sort type
ProductReportSortType _mapSortOptionToSqlType(ProductReportSortOption option) {
  switch (option) {
    case ProductReportSortOption.quantity:
      return ProductReportSortType.quantity;
    case ProductReportSortOption.revenue:
      return ProductReportSortType.revenue;
    case ProductReportSortOption.profit:
      return ProductReportSortType.profit;
    case ProductReportSortOption.profitMargin:
      return ProductReportSortType.quantity; // Default, handle client-side
  }
}
