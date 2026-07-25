import 'package:dartz/dartz.dart';

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
  Future<Either<Failure, List<Transaction>>> getTransactionsByPaymentStatus(
    String status,
  );

  /// Update a transaction (e.g., mark debt as paid)
  Future<Either<Failure, Transaction>> updateTransaction(
    String id, {
    String? paymentStatus,
    DateTime? debtPaidAt,
  });
}
