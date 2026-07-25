import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/date_filter.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/get_transaction.dart';
import '../../domain/usecases/get_transactions.dart';

/// Provider for date filter state
final dateFilterProvider = StateProvider.autoDispose<DateFilter>(
  (ref) => DateFilter.today,
);

/// Provider for custom date range (used when dateFilter is custom)
final customDateRangeProvider = StateProvider.autoDispose<DateTimeRange?>(
  (ref) => null,
);

/// Provider for transactions based on current date filter
final transactionsProvider =
    FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final dateFilter = ref.watch(dateFilterProvider);
  final customRange = ref.watch(customDateRangeProvider);

  // Determine date range
  DateTimeRange range;
  if (dateFilter == DateFilter.custom && customRange != null) {
    // Use custom range with end of day for end date
    final endOfDay = DateTime(
      customRange.end.year,
      customRange.end.month,
      customRange.end.day,
      23,
      59,
      59,
      999,
    );
    range = DateTimeRange(start: customRange.start, end: endOfDay);
  } else {
    range = dateFilter.range;
  }

  final useCase = getIt<GetTransactions>();
  final result = await useCase(GetTransactionsParams(
    startDate: range.start,
    endDate: range.end,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (transactions) => transactions,
  );
});

/// Provider for a single transaction by ID (with items)
final transactionDetailProvider =
    FutureProvider.autoDispose.family<Transaction, String>((ref, id) async {
  final useCase = getIt<GetTransactionById>();
  final result = await useCase(GetTransactionByIdParams(id: id));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (transaction) => transaction,
  );
});

/// Provider for transactions grouped by date
/// Returns a Map where key is the date (without time) and value is list of transactions
final groupedTransactionsProvider =
    FutureProvider.autoDispose<Map<DateTime, List<Transaction>>>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);

  final grouped = <DateTime, List<Transaction>>{};
  for (final txn in transactions) {
    final dateKey = DateTime(
      txn.transactionDate.year,
      txn.transactionDate.month,
      txn.transactionDate.day,
    );
    grouped.putIfAbsent(dateKey, () => []).add(txn);
  }

  // Sort keys descending (newest first)
  final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  // Return map with sorted keys
  return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
});

/// Provider for total transaction count in current filter
final transactionCountProvider = Provider.autoDispose<int>((ref) {
  final transactions = ref.watch(transactionsProvider).valueOrNull;
  return transactions?.length ?? 0;
});

/// Provider for total revenue in current filter
final totalRevenueProvider = Provider.autoDispose<double>((ref) {
  final transactions = ref.watch(transactionsProvider).valueOrNull;
  if (transactions == null) return 0;
  return transactions.fold(0.0, (sum, txn) => sum + txn.total);
});
