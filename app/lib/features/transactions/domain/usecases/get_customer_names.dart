import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/transaction_repository.dart';

/// Names this shop has already recorded against a sale.
///
/// Exists to feed an autocomplete, which exists to stop free text fragmenting:
/// without it "Bu Sri", "bu sri" and "Bu Sri " are three customers, and the
/// customer filter on the transaction list slowly stops being useful.
class GetCustomerNames
    implements UseCase<List<String>, GetCustomerNamesParams> {
  final TransactionRepository _repository;

  GetCustomerNames(this._repository);

  @override
  Future<Either<Failure, List<String>>> call(
    GetCustomerNamesParams params,
  ) async {
    return _repository.getCustomerNames(
      query: params.query,
      limit: params.limit,
    );
  }
}

/// Parameters for [GetCustomerNames]
class GetCustomerNamesParams extends Equatable {
  /// Substring to match, unanchored. Null returns the most recent names.
  final String? query;

  /// How many to return.
  ///
  /// Small on purpose: this is a suggestion list under a text field, not a
  /// directory. A cashier scanning more than a handful is faster off typing.
  final int limit;

  const GetCustomerNamesParams({this.query, this.limit = 20});

  @override
  List<Object?> get props => [query, limit];
}
