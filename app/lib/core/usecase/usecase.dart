import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../errors/failures.dart';

/// Base class for all use cases
///
/// [T] is the return type of the use case
/// [Params] is the parameters required by the use case
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Use case that doesn't require any parameters
abstract class UseCaseNoParams<T> {
  Future<Either<Failure, T>> call();
}

/// Use case for streaming data
abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

/// Parameters class for use cases that don't need params
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
