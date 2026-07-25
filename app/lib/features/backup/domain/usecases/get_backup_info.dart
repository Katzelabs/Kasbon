import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/backup_metadata.dart';
import '../repositories/backup_repository.dart';

/// Parameters for get backup info use case
class GetBackupInfoParams extends Equatable {
  final String filePath;

  const GetBackupInfoParams({required this.filePath});

  @override
  List<Object?> get props => [filePath];
}

/// Use case for getting backup info for preview
class GetBackupInfo extends UseCase<BackupInfo, GetBackupInfoParams> {
  final BackupRepository repository;

  GetBackupInfo(this.repository);

  @override
  Future<Either<Failure, BackupInfo>> call(GetBackupInfoParams params) async {
    return await repository.getBackupInfo(params.filePath);
  }
}
