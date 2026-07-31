import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case to email a password-recovery code.
///
/// Succeeds for unregistered addresses too - Supabase answers an unknown email
/// with a plain success, and the UI must not undo that by reporting a failure
/// only real accounts avoid.
class RequestPasswordReset
    implements UseCase<void, RequestPasswordResetParams> {
  final AuthRepository _repository;

  RequestPasswordReset(this._repository);

  @override
  Future<Either<Failure, void>> call(RequestPasswordResetParams params) {
    return _repository.requestPasswordReset(email: params.email);
  }
}

/// Parameters for the RequestPasswordReset use case.
class RequestPasswordResetParams extends Equatable {
  final String email;

  const RequestPasswordResetParams({required this.email});

  @override
  List<Object?> get props => [email];
}
