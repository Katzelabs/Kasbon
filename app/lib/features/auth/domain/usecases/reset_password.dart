import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Use case to redeem a recovery code and set a new password.
class ResetPassword implements UseCase<UserProfile, ResetPasswordParams> {
  final AuthRepository _repository;

  ResetPassword(this._repository);

  @override
  Future<Either<Failure, UserProfile>> call(ResetPasswordParams params) {
    return _repository.resetPassword(
      email: params.email,
      token: params.token,
      newPassword: params.newPassword,
    );
  }
}

/// Parameters for the ResetPassword use case.
class ResetPasswordParams extends Equatable {
  final String email;
  final String token;
  final String newPassword;

  const ResetPasswordParams({
    required this.email,
    required this.token,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [email, token, newPassword];
}
