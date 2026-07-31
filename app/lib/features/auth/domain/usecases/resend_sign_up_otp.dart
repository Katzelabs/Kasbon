import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case to send a fresh sign-up confirmation code.
class ResendSignUpOtp implements UseCase<void, ResendSignUpOtpParams> {
  final AuthRepository _repository;

  ResendSignUpOtp(this._repository);

  @override
  Future<Either<Failure, void>> call(ResendSignUpOtpParams params) {
    return _repository.resendSignUpOtp(email: params.email);
  }
}

/// Parameters for the ResendSignUpOtp use case.
class ResendSignUpOtpParams extends Equatable {
  final String email;

  const ResendSignUpOtpParams({required this.email});

  @override
  List<Object?> get props => [email];
}
