import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';

/// Use case to mark a debt transaction as paid
class MarkDebtPaid implements UseCase<Transaction, MarkDebtPaidParams> {
  final TransactionRepository _repository;

  MarkDebtPaid(this._repository);

  @override
  Future<Either<Failure, Transaction>> call(MarkDebtPaidParams params) async {
    return _repository.updateTransaction(
      params.transactionId,
      paymentStatus: 'paid',
      debtPaidAt: DateTime.now(),
    );
  }
}

/// Parameters for MarkDebtPaid use case
class MarkDebtPaidParams extends Equatable {
  /// The transaction ID to mark as paid
  final String transactionId;

  const MarkDebtPaidParams({required this.transactionId});

  @override
  List<Object?> get props => [transactionId];
}
