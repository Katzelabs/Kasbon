import 'package:dartz/dartz.dart';

import '../../../../core/constants/query_limits.dart';
import '../../../../core/errors/failures.dart';
import '../entities/transaction.dart';
import '../entities/transaction_item.dart';

/// Abstract repository interface for Transaction operations
abstract class TransactionRepository {
  /// Create a new transaction with all its items
  /// Atomically creates transaction, items, and updates stock
  Future<Either<Failure, Transaction>> createTransaction(
    Transaction transaction,
    List<TransactionItem> items,
  );

  /// Get all transactions with optional pagination
  Future<Either<Failure, List<Transaction>>> getTransactions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get a single transaction by ID (including items)
  Future<Either<Failure, Transaction>> getTransactionById(String id);

  /// Get today's transaction count (for generating transaction number)
  Future<Either<Failure, int>> getTodayTransactionCount();

  /// Get transactions by payment status (e.g., 'debt' for unpaid debts)
  ///
  /// [limit] and [offset] are how a caller walks a status that can grow without
  /// bound. Omitting them asks the server for everything, which PostgREST
  /// answers by silently truncating at its `max_rows` - see [QueryLimits].
  Future<Either<Failure, List<Transaction>>> getTransactionsByPaymentStatus(
    String status, {
    int? limit,
    int? offset,
  });

  /// Update a transaction (e.g., mark debt as paid, attach a payment proof)
  ///
  /// Only the named fields are written; anything omitted is left alone.
  Future<Either<Failure, Transaction>> updateTransaction(
    String id, {
    String? paymentStatus,
    DateTime? debtPaidAt,
    String? paymentProofPath,
    DateTime? paymentConfirmedAt,
    String? paymentConfirmedBy,
  });

  /// Distinct customer names already used by this shop, most recent first.
  ///
  /// Feeds the POS name autocomplete, which exists so that one customer stays
  /// one name rather than becoming three spellings of it.
  Future<Either<Failure, List<String>>> getCustomerNames({
    String? query,
    int limit,
  });
}
