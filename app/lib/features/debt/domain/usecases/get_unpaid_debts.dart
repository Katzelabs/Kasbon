import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';

/// Use case to get all unpaid debt transactions
class GetUnpaidDebts implements UseCase<List<Transaction>, NoParams> {
  final TransactionRepository _repository;

  GetUnpaidDebts(this._repository);

  @override
  Future<Either<Failure, List<Transaction>>> call(NoParams params) async {
    return _repository.getTransactionsByPaymentStatus('debt');
  }
}

/// No parameters needed for this use case
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
