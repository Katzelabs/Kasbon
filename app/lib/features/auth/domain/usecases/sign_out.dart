import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case to sign out the current user.
class SignOut implements UseCaseNoParams<void> {
  final AuthRepository _repository;

  SignOut(this._repository);

  @override
  Future<Either<Failure, void>> call() {
    return _repository.signOut();
  }
}
