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

  /// Detach the payment proof from a sale, leaving the sale itself untouched.
  ///
  /// Separate from [updateTransaction] rather than a null argument to it,
  /// because null there means "leave this column alone" - the property that
  /// lets a slow proof upload and a debt settlement write the same row without
  /// clobbering each other. A method that erases has to be able to say so.
  ///
  /// This clears the path only. `payment_confirmed_at` and
  /// `payment_confirmed_by` survive: a shop owner deleting a blurry photo is
  /// not retracting the confirmation, and blanking those would make a sale that
  /// was verified at the counter read as unverified.
  ///
  /// Does not touch the stored object - the caller owns that, and does it after
  /// this returns, so a failed delete leaves an unreferenced file rather than a
  /// row pointing at nothing.
  Future<Either<Failure, Transaction>> clearPaymentProof(String id);

  /// Distinct customer names already used by this shop, most recent first.
  ///
  /// Feeds the POS name autocomplete, which exists so that one customer stays
  /// one name rather than becoming three spellings of it.
  Future<Either<Failure, List<String>>> getCustomerNames({
    String? query,
    int limit,
  });
}
