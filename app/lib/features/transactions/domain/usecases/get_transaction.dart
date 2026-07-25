import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Use case to get a transaction by ID (including its items)
class GetTransactionById implements UseCase<Transaction, GetTransactionByIdParams> {
  final TransactionRepository _repository;

  GetTransactionById(this._repository);

  @override
  Future<Either<Failure, Transaction>> call(GetTransactionByIdParams params) {
    return _repository.getTransactionById(params.id);
  }
}

/// Parameters for GetTransactionById use case
class GetTransactionByIdParams extends Equatable {
  final String id;

  const GetTransactionByIdParams({required this.id});

  @override
  List<Object?> get props => [id];
}
