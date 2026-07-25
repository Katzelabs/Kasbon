import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Use case to sign in with email and password.
class SignIn implements UseCase<UserProfile, SignInParams> {
  final AuthRepository _repository;

  SignIn(this._repository);

  @override
  Future<Either<Failure, UserProfile>> call(SignInParams params) {
    return _repository.signIn(
      email: params.email,
      password: params.password,
    );
  }
}

/// Parameters for the SignIn use case.
class SignInParams extends Equatable {
  final String email;
  final String password;

  const SignInParams({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}
