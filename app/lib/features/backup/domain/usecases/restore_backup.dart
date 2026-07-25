import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/backup_repository.dart';

/// Parameters for restore backup use case
class RestoreBackupParams extends Equatable {
  final String filePath;
  final void Function(String step, double progress)? onProgress;

  const RestoreBackupParams({
    required this.filePath,
    this.onProgress,
  });

  @override
  List<Object?> get props => [filePath];
}

/// Use case for restoring a backup
class RestoreBackup extends UseCase<void, RestoreBackupParams> {
  final BackupRepository repository;

  RestoreBackup(this.repository);

  @override
  Future<Either<Failure, void>> call(RestoreBackupParams params) async {
    return await repository.restoreBackup(
      params.filePath,
      onProgress: params.onProgress,
    );
  }
}
