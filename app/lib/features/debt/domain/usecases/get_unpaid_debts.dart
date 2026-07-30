import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/query_limits.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';

/// Use case to get all unpaid debt transactions
///
/// ## Why this pages rather than asking for everything
///
/// The debt screen does not just list these - it sums them into the total owed,
/// counts the distinct customers and finds the oldest outstanding debt. Those
/// three figures are only right if the list is complete.
///
/// A single unbounded read is not complete: PostgREST truncates at
/// [QueryLimits.supabaseMaxRows] without saying so, so a shop carrying more
/// open hutang than that was shown a total that was too small - on the one
/// screen where a number being too small is the whole problem.
///
/// So it walks the set in [QueryLimits.chunkSize] pages up to
/// [QueryLimits.debtCeiling], and reports reaching the ceiling through
/// [UnpaidDebtsResult.isTruncated] so the screen can say the totals are partial
/// rather than presenting them as the full picture.
class GetUnpaidDebts implements UseCase<UnpaidDebtsResult, NoParams> {
  final TransactionRepository _repository;

  GetUnpaidDebts(this._repository);

  @override
  Future<Either<Failure, UnpaidDebtsResult>> call(NoParams params) async {
    final debts = <Transaction>[];

    while (debts.length < QueryLimits.debtCeiling) {
      final remaining = QueryLimits.debtCeiling - debts.length;
      final pageSize =
          remaining < QueryLimits.chunkSize ? remaining : QueryLimits.chunkSize;

      final result = await _repository.getTransactionsByPaymentStatus(
        'debt',
        limit: pageSize,
        offset: debts.length,
      );

      // A failure part-way through propagates rather than returning the rows
      // already collected: a half-fetched debt list would be summed into a
      // total that reads as authoritative and is silently short.
      final page = result.fold<List<Transaction>?>((_) => null, (rows) => rows);
      if (page == null) {
        return result.map((rows) => UnpaidDebtsResult(debts: rows));
      }

      debts.addAll(page);

      // A short page means the server had nothing more to give.
      if (page.length < pageSize) {
        return Right(UnpaidDebtsResult(debts: debts));
      }
    }

    return Right(UnpaidDebtsResult(debts: debts, isTruncated: true));
  }
}

/// The unpaid debts, and whether they are all of them.
class UnpaidDebtsResult extends Equatable {
  /// The debts fetched, newest first.
  final List<Transaction> debts;

  /// True when [QueryLimits.debtCeiling] was reached and older debts remain
  /// unfetched, which makes every total derived from [debts] a lower bound.
  final bool isTruncated;

  const UnpaidDebtsResult({
    required this.debts,
    this.isTruncated = false,
  });

  @override
  List<Object?> get props => [debts, isTruncated];
}

/// No parameters needed for this use case
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
