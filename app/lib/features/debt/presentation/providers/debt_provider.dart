import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/debt_summary.dart';
import '../../domain/usecases/get_unpaid_debts.dart';
import '../../domain/usecases/mark_debt_paid.dart';

/// Provider for unpaid debts
final unpaidDebtsProvider =
    FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final useCase = getIt<GetUnpaidDebts>();
  final result = await useCase(const NoParams());

  return result.fold(
    (failure) => throw Exception(failure.message),
    (debts) => debts,
  );
});

/// Provider for debt summary statistics
final debtSummaryProvider = FutureProvider.autoDispose<DebtSummary>((ref) async {
  final debtsAsync = await ref.watch(unpaidDebtsProvider.future);
  final debts = debtsAsync;

  if (debts.isEmpty) {
    return const DebtSummary.empty();
  }

  // Calculate summary
  final totalDebt = debts.fold<double>(0, (sum, t) => sum + t.total);

  // Get unique customers
  final customers = <String>{};
  for (final debt in debts) {
    if (debt.customerName != null && debt.customerName!.isNotEmpty) {
      customers.add(debt.customerName!);
    }
  }

  // Find oldest debt
  DateTime? oldestDate;
  for (final debt in debts) {
    if (oldestDate == null || debt.transactionDate.isBefore(oldestDate)) {
      oldestDate = debt.transactionDate;
    }
  }

  return DebtSummary(
    totalDebt: totalDebt,
    customerCount: customers.length,
    transactionCount: debts.length,
    oldestDebtDate: oldestDate,
  );
});

/// Provider for debts grouped by customer name
final debtsByCustomerProvider =
    FutureProvider.autoDispose<Map<String, List<Transaction>>>((ref) async {
  final debts = await ref.watch(unpaidDebtsProvider.future);

  final grouped = <String, List<Transaction>>{};
  for (final debt in debts) {
    final customerName = debt.customerName ?? 'Tidak Diketahui';
    if (!grouped.containsKey(customerName)) {
      grouped[customerName] = [];
    }
    grouped[customerName]!.add(debt);
  }

  return grouped;
});

/// Provider for unpaid debt count (for badge display)
final unpaidDebtCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final debts = await ref.watch(unpaidDebtsProvider.future);
  return debts.length;
});

/// State for marking debt as paid
class MarkDebtPaidState {
  final bool isLoading;
  final String? error;
  final Transaction? markedTransaction;

  const MarkDebtPaidState({
    this.isLoading = false,
    this.error,
    this.markedTransaction,
  });

  MarkDebtPaidState copyWith({
    bool? isLoading,
    String? error,
    Transaction? markedTransaction,
  }) {
    return MarkDebtPaidState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      markedTransaction: markedTransaction ?? this.markedTransaction,
    );
  }
}

/// Notifier for marking debt as paid
class MarkDebtPaidNotifier extends StateNotifier<MarkDebtPaidState> {
  final Ref _ref;

  MarkDebtPaidNotifier(this._ref) : super(const MarkDebtPaidState());

  /// Mark a debt transaction as paid
  Future<bool> markAsPaid(String transactionId) async {
    state = const MarkDebtPaidState(isLoading: true);

    final useCase = getIt<MarkDebtPaid>();
    final result = await useCase(MarkDebtPaidParams(transactionId: transactionId));

    return result.fold(
      (failure) {
        state = MarkDebtPaidState(error: failure.message);
        return false;
      },
      (transaction) {
        state = MarkDebtPaidState(markedTransaction: transaction);
        // Invalidate the debts provider to refresh the list
        _ref.invalidate(unpaidDebtsProvider);
        return true;
      },
    );
  }

  /// Reset state
  void reset() {
    state = const MarkDebtPaidState();
  }
}

/// Provider for mark debt paid state
final markDebtPaidProvider =
    StateNotifierProvider.autoDispose<MarkDebtPaidNotifier, MarkDebtPaidState>(
        (ref) {
  return MarkDebtPaidNotifier(ref);
});
