import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/backup_metadata.dart';
import '../repositories/backup_repository.dart';

/// Use case for getting current data counts
class GetDataCounts extends UseCase<DataCounts, NoParams> {
  final BackupRepository repository;

  GetDataCounts(this.repository);

  @override
  Future<Either<Failure, DataCounts>> call(NoParams params) async {
    return await repository.getCurrentDataCounts();
  }
}
