import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Use case to register a new user account.
class SignUp implements UseCase<UserProfile, SignUpParams> {
  final AuthRepository _repository;

  SignUp(this._repository);

  @override
  Future<Either<Failure, UserProfile>> call(SignUpParams params) {
    return _repository.signUp(
      email: params.email,
      password: params.password,
      fullName: params.fullName,
      phone: params.phone,
    );
  }
}

/// Parameters for the SignUp use case.
class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String fullName;
  final String? phone;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.fullName,
    this.phone,
  });

  @override
  List<Object?> get props => [email, password, fullName, phone];
}
