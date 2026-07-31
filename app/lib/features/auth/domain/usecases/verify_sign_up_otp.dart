import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Use case to confirm a sign-up with the emailed 6-digit code.
class VerifySignUpOtp implements UseCase<UserProfile, VerifySignUpOtpParams> {
  final AuthRepository _repository;

  VerifySignUpOtp(this._repository);

  @override
  Future<Either<Failure, UserProfile>> call(VerifySignUpOtpParams params) {
    return _repository.verifySignUpOtp(
      email: params.email,
      token: params.token,
    );
  }
}

/// Parameters for the VerifySignUpOtp use case.
class VerifySignUpOtpParams extends Equatable {
  final String email;
  final String token;

  const VerifySignUpOtpParams({
    required this.email,
    required this.token,
  });

  @override
  List<Object?> get props => [email, token];
}
