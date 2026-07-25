import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Use case to get transactions with optional date filtering and pagination
class GetTransactions implements UseCase<List<Transaction>, GetTransactionsParams> {
  final TransactionRepository _repository;

  GetTransactions(this._repository);

  @override
  Future<Either<Failure, List<Transaction>>> call(GetTransactionsParams params) {
    return _repository.getTransactions(
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
      offset: params.offset,
    );
  }
}

/// Parameters for GetTransactions use case
class GetTransactionsParams extends Equatable {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
  final int? offset;

  const GetTransactionsParams({
    this.startDate,
    this.endDate,
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [startDate, endDate, limit, offset];
}
