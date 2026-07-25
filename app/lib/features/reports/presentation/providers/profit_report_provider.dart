import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/product_profitability.dart';
import '../../domain/entities/profit_summary.dart';
import '../../domain/usecases/get_product_profitability.dart';
import '../../domain/usecases/get_profit_summary.dart';
import '../../domain/usecases/get_top_profitable_products.dart';
import 'date_range_provider.dart';

/// Provider for profit summary based on selected date range
final profitSummaryByDateRangeProvider =
    FutureProvider.autoDispose<ProfitSummary>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  final useCase = getIt<GetProfitSummary>();
  final result = await useCase(dateRange.toParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Provider for today's profit summary
final todayProfitSummaryProvider =
    FutureProvider.autoDispose<ProfitSummary>((ref) async {
  final useCase = getIt<GetProfitSummary>();
  final result = await useCase(DateRangeParams.today());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Provider for this month's profit summary
final monthlyProfitSummaryProvider =
    FutureProvider.autoDispose<ProfitSummary>((ref) async {
  final useCase = getIt<GetProfitSummary>();
  final result = await useCase(DateRangeParams.thisMonth());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Provider for this week's profit summary
final weeklyProfitSummaryProvider =
    FutureProvider.autoDispose<ProfitSummary>((ref) async {
  final useCase = getIt<GetProfitSummary>();
  final result = await useCase(DateRangeParams.thisWeek());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Provider for top 5 profitable products
final topProfitableProductsProvider =
    FutureProvider.autoDispose<List<ProductProfitability>>((ref) async {
  final useCase = getIt<GetTopProfitableProducts>();
  final result = await useCase(5);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

/// Provider for top 10 profitable products
final top10ProfitableProductsProvider =
    FutureProvider.autoDispose<List<ProductProfitability>>((ref) async {
  final useCase = getIt<GetTopProfitableProducts>();
  final result = await useCase(10);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

/// Provider for a specific product's profitability
final productProfitabilityProvider = FutureProvider.autoDispose
    .family<ProductProfitability, String>((ref, productId) async {
  final useCase = getIt<GetProductProfitability>();
  final result = await useCase(productId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (profitability) => profitability,
  );
});
