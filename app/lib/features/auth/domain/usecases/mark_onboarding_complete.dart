import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case to record that the user has finished the onboarding wizard.
class MarkOnboardingComplete implements UseCaseNoParams<void> {
  final AuthRepository _repository;

  MarkOnboardingComplete(this._repository);

  @override
  Future<Either<Failure, void>> call() {
    return _repository.markOnboardingComplete();
  }
}
