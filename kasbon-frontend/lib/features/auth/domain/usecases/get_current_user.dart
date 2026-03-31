import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Use case to get the currently authenticated user's profile.
class GetCurrentUser implements UseCaseNoParams<UserProfile?> {
  final AuthRepository _repository;

  GetCurrentUser(this._repository);

  @override
  Future<Either<Failure, UserProfile?>> call() {
    return _repository.getCurrentUser();
  }
}
