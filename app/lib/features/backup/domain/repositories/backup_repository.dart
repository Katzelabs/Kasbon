import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/backup_metadata.dart';

/// Progress callback for restore operations
typedef RestoreProgressCallback = void Function(String step, double progress);

/// Abstract repository for backup/restore operations
abstract class BackupRepository {
  /// Creates a backup of all data and returns the backup metadata
  /// If [directoryPath] is provided, saves to that directory instead of default
  Future<Either<Failure, BackupMetadata>> createBackup({
    String? directoryPath,
  });

  /// Restores data from a backup file
  /// [filePath] - Path to the backup file
  /// [onProgress] - Optional callback for progress updates
  Future<Either<Failure, void>> restoreBackup(
    String filePath, {
    RestoreProgressCallback? onProgress,
  });

  /// Gets backup info from a file for preview
  Future<Either<Failure, BackupInfo>> getBackupInfo(String filePath);

  /// Gets the last backup metadata, or null if no backups exist
  Future<Either<Failure, BackupMetadata?>> getLastBackupInfo();

  /// Gets current data counts from the database
  Future<Either<Failure, DataCounts>> getCurrentDataCounts();

  /// Clears all data from the database
  Future<Either<Failure, void>> clearAllData({
    RestoreProgressCallback? onProgress,
  });
}
