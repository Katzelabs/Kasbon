import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/get_dashboard_summary.dart';

/// Provider for dashboard summary - main data provider
/// Uses autoDispose to clean up when not in use
final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final useCase = getIt<GetDashboardSummary>();
  final result = await useCase();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Provider for today's sales (derived from summary)
final todaySalesProvider = Provider.autoDispose<double>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.todaySales ?? 0;
});

/// Provider for today's profit (derived from summary)
final todayProfitProvider = Provider.autoDispose<double>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.todayProfit ?? 0;
});

/// Provider for transaction count (derived from summary)
final transactionCountProvider = Provider.autoDispose<int>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.transactionCount ?? 0;
});

/// Provider for yesterday's sales (derived from summary)
final yesterdaySalesProvider = Provider.autoDispose<double>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.yesterdaySales ?? 0;
});

/// Provider for comparison percentage (derived from summary)
final comparisonPercentageProvider = Provider.autoDispose<double?>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.comparisonPercentage;
});

/// Provider for isIncrease flag (derived from summary)
final isIncreaseProvider = Provider.autoDispose<bool>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.isIncrease ?? true;
});

/// Provider for low stock count (derived from summary)
final lowStockCountProvider = Provider.autoDispose<int>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.lowStockCount ?? 0;
});

/// Provider for hasLowStock flag (derived from summary)
final hasLowStockProvider = Provider.autoDispose<bool>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
  return summary?.hasLowStock ?? false;
});
