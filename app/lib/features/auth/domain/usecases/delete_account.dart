import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case to permanently delete the signed-in account.
///
/// Google Play requires an in-app route to this and Apple requires it of any
/// app that creates accounts, which is why it exists - but the deletion is real
/// and total: the auth row, every table that cascades off it, and both storage
/// folders. There is no undo and no grace period.
class DeleteAccount implements UseCase<void, DeleteAccountParams> {
  final AuthRepository _repository;

  DeleteAccount(this._repository);

  @override
  Future<Either<Failure, void>> call(DeleteAccountParams params) {
    return _repository.deleteAccount(password: params.password);
  }
}

/// Parameters for the DeleteAccount use case.
class DeleteAccountParams extends Equatable {
  /// The account's current password, re-entered to authorise the deletion.
  final String password;

  const DeleteAccountParams({required this.password});

  @override
  List<Object?> get props => [password];
}
