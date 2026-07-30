import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/constants/query_limits.dart';
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

/// The window the history list is currently showing.
///
/// Split out of the fetch so the notifier can compare the resolved range rather
/// than the two pieces of state that produce it - picking "Hari Ini" while
/// already on "Hari Ini" should not throw the loaded pages away.
DateTimeRange _resolveRange(DateFilter filter, DateTimeRange? custom) {
  if (filter == DateFilter.custom && custom != null) {
    return DateTimeRange(
      start: custom.start,
      end: DateTime(
        custom.end.year,
        custom.end.month,
        custom.end.day,
        23,
        59,
        59,
        999,
      ),
    );
  }
  return filter.range;
}

/// One page-worth of transaction history, plus what the list needs to ask for
/// the next one.
class TransactionListState extends Equatable {
  /// Every transaction loaded so far, newest first.
  final List<Transaction> transactions;

  /// A first page is in flight; the list has nothing to show yet.
  final bool isLoading;

  /// A subsequent page is in flight; the list keeps what it has.
  final bool isLoadingMore;

  /// Whether the server had a full page left to give.
  final bool hasMore;

  /// Last page loaded, 1-based. Zero before the first load lands.
  final int currentPage;

  final String? error;

  const TransactionListState({
    this.transactions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  TransactionListState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
    bool clearError = false,
  }) {
    return TransactionListState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [transactions, isLoading, isLoadingMore, hasMore, currentPage, error];
}

/// Loads transaction history a page at a time.
///
/// ## Why this is not a `FutureProvider` any more
///
/// It used to be one, calling [GetTransactions] with no `limit` at all. That
/// read is unbounded in the app and bounded on the server: PostgREST stops at
/// [QueryLimits.supabaseMaxRows] and returns a plain 200, so the history of a
/// shop past a thousand sales in the selected window arrived silently cut, and
/// the whole set was decoded and held in memory on every visit to the screen.
///
/// A till runs all day on a cheap phone, and "Bulan Ini" on a busy warung
/// clears a thousand rows well before the month does.
class TransactionListNotifier extends StateNotifier<TransactionListState> {
  final GetTransactions _getTransactions;
  final Ref _ref;

  DateTimeRange _range;

  /// Bumped every time the list starts over.
  ///
  /// Requests already in flight when the filter changes still resolve, and
  /// without this the reply to "Hari Ini" could land after the reply to "Bulan
  /// Ini" and be appended under it. The date chips are one tap apart, so that
  /// race is a tap away rather than a theoretical one - the old
  /// `FutureProvider` got the same protection for free, because Riverpod threw
  /// the whole future away on rebuild.
  int _generation = 0;

  TransactionListNotifier(this._getTransactions, this._ref)
      : _range = _resolveRange(
          _ref.read(dateFilterProvider),
          _ref.read(customDateRangeProvider),
        ),
        super(const TransactionListState()) {
    _ref.listen(dateFilterProvider, (_, __) => _onRangeMaybeChanged());
    _ref.listen(customDateRangeProvider, (_, __) => _onRangeMaybeChanged());

    loadInitial();
  }

  void _onRangeMaybeChanged() {
    final next = _resolveRange(
      _ref.read(dateFilterProvider),
      _ref.read(customDateRangeProvider),
    );
    if (next.start == _range.start && next.end == _range.end) return;
    _range = next;
    reset();
  }

  /// Load the first page, discarding anything already loaded.
  Future<void> loadInitial() async {
    _generation++;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      transactions: [],
      currentPage: 0,
      hasMore: true,
    );
    await _loadPage(page: 1, isInitial: true);
  }

  /// Load the next page onto the end of the list.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    await _loadPage(page: state.currentPage + 1, isInitial: false);
  }

  /// Reload from the first page - pull-to-refresh, and filter changes.
  Future<void> reset() => loadInitial();

  Future<void> _loadPage({required int page, required bool isInitial}) async {
    const pageSize = QueryLimits.transactionPageSize;
    final generation = _generation;

    final result = await _getTransactions(GetTransactionsParams(
      startDate: _range.start,
      endDate: _range.end,
      limit: pageSize,
      offset: (page - 1) * pageSize,
    ));

    // The window moved while this was in flight; these rows answer a question
    // nobody is asking any more.
    if (!mounted || generation != _generation) return;

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: failure.message,
        );
      },
      (rows) {
        state = state.copyWith(
          transactions:
              isInitial ? rows : [...state.transactions, ...rows],
          isLoading: false,
          isLoadingMore: false,
          // A short page is the end of the set. Asking for a count as well
          // would double every request for a fact the page length already
          // carries.
          hasMore: rows.length == pageSize,
          currentPage: page,
          clearError: true,
        );
      },
    );
  }
}

/// Provider for the paginated transaction history.
final transactionListProvider = StateNotifierProvider.autoDispose<
    TransactionListNotifier, TransactionListState>((ref) {
  return TransactionListNotifier(getIt<GetTransactions>(), ref);
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

/// The loaded transactions, grouped under their date for the sticky headers.
///
/// Derived from the pages already fetched rather than from a fetch of its own,
/// so a page arriving mid-scroll extends the last group instead of restarting
/// the list. Rows arrive newest-first and stay in that order within a group,
/// so nothing here needs to sort them.
final groupedTransactionsProvider =
    Provider.autoDispose<Map<DateTime, List<Transaction>>>((ref) {
  final transactions =
      ref.watch(transactionListProvider.select((s) => s.transactions));

  final grouped = <DateTime, List<Transaction>>{};
  for (final txn in transactions) {
    final dateKey = DateTime(
      txn.transactionDate.year,
      txn.transactionDate.month,
      txn.transactionDate.day,
    );
    grouped.putIfAbsent(dateKey, () => []).add(txn);
  }

  final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
});
