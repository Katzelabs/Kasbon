import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/backup_metadata.dart';
import '../repositories/backup_repository.dart';

/// Parameters for creating a backup
class CreateBackupParams extends Equatable {
  /// Optional directory path to save the backup
  /// If null, uses default backup directory
  final String? directoryPath;

  const CreateBackupParams({this.directoryPath});

  @override
  List<Object?> get props => [directoryPath];
}

/// Use case for creating a backup
class CreateBackup extends UseCase<BackupMetadata, CreateBackupParams> {
  final BackupRepository repository;

  CreateBackup(this.repository);

  @override
  Future<Either<Failure, BackupMetadata>> call(CreateBackupParams params) async {
    return await repository.createBackup(directoryPath: params.directoryPath);
  }
}
