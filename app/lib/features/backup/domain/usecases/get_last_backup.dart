import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/backup_metadata.dart';
import '../repositories/backup_repository.dart';

/// Use case for getting the last backup info
class GetLastBackup extends UseCase<BackupMetadata?, NoParams> {
  final BackupRepository repository;

  GetLastBackup(this.repository);

  @override
  Future<Either<Failure, BackupMetadata?>> call(NoParams params) async {
    return await repository.getLastBackupInfo();
  }
}
