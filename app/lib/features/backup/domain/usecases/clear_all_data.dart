import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/backup_repository.dart';

/// Parameters for clear all data use case
class ClearAllDataParams extends Equatable {
  final void Function(String step, double progress)? onProgress;

  const ClearAllDataParams({this.onProgress});

  @override
  List<Object?> get props => [];
}

/// Use case for clearing all data from the database
class ClearAllData extends UseCase<void, ClearAllDataParams> {
  final BackupRepository repository;

  ClearAllData(this.repository);

  @override
  Future<Either<Failure, void>> call(ClearAllDataParams params) async {
    return await repository.clearAllData(onProgress: params.onProgress);
  }
}
