import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/backup_service.dart' hide RestoreProgressCallback;
import '../../../../core/services/file_export/file_export_service.dart';
import '../../domain/entities/backup_metadata.dart';
import '../../domain/repositories/backup_repository.dart';

/// Implementation of BackupRepository
class BackupRepositoryImpl implements BackupRepository {
  final BackupService _backupService;

  BackupRepositoryImpl(this._backupService);

  @override
  Future<Either<Failure, BackupMetadata>> createBackup({
    String? directoryPath,
  }) async {
    try {
      // Export data to JSON
      final jsonContent = await _backupService.exportToJson();

      // Generate filename and save
      final filename = FileExportService.generateBackupFilename();
      final saved = await FileExportService.saveText(
        jsonContent,
        filename,
        directory: directoryPath,
      );

      // Get file size. Zero where the platform gave us no path back - the
      // backup still exists, we just cannot stat a browser download.
      final fileSize = saved.hasPath
          ? await FileExportService.getFileSize(saved.path!)
          : 0;

      // Parse metadata from the JSON
      final metadataDto = _backupService.parseBackupInfo(jsonContent);

      // Build BackupMetadata entity
      final metadata = BackupMetadata(
        filePath: saved.path,
        fileName: filename,
        backupDate: DateTime.parse(metadataDto.backupDate),
        appVersion: metadataDto.appVersion,
        deviceInfo: metadataDto.deviceInfo,
        counts: BackupCounts(
          shopSettings: metadataDto.counts['shop_settings'] ?? 0,
          categories: metadataDto.counts['categories'] ?? 0,
          products: metadataDto.counts['products'] ?? 0,
          transactions: metadataDto.counts['transactions'] ?? 0,
          transactionItems: metadataDto.counts['transaction_items'] ?? 0,
        ),
        fileSizeBytes: fileSize,
      );

      return Right(metadata);
    } on BackupException catch (e) {
      return Left(BackupFailure(message: e.message, code: e.code));
    } on FileException catch (e) {
      return Left(FileFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> restoreBackup(
    String filePath, {
    RestoreProgressCallback? onProgress,
  }) async {
    // Restore is not supported in Supabase-only mode.
    // Data lives in the cloud and is managed server-side.
    return const Left(BackupFailure(
      message: 'Restore tidak didukung. Data tersimpan di cloud.',
      code: 'RESTORE_NOT_SUPPORTED',
    ));
  }

  @override
  Future<Either<Failure, BackupInfo>> getBackupInfo(String filePath) async {
    try {
      final jsonContent = await FileExportService.readFile(filePath);
      final metadataDto = _backupService.parseBackupInfo(jsonContent);

      final info = BackupInfo(
        backupDate: DateTime.parse(metadataDto.backupDate),
        appVersion: metadataDto.appVersion,
        productsCount: metadataDto.counts['products'] ?? 0,
        transactionsCount: metadataDto.counts['transactions'] ?? 0,
        categoriesCount: metadataDto.counts['categories'] ?? 0,
      );

      return Right(info);
    } on BackupException catch (e) {
      return Left(BackupFailure(message: e.message, code: e.code));
    } on FileException catch (e) {
      return Left(FileFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, BackupMetadata?>> getLastBackupInfo() async {
    try {
      final lastFile = await FileExportService.findLastBackup();

      if (lastFile == null) {
        return const Right(null);
      }

      final jsonContent = await FileExportService.readFile(lastFile.path);
      final metadataDto = _backupService.parseBackupInfo(jsonContent);

      final metadata = BackupMetadata(
        filePath: lastFile.path,
        fileName: lastFile.fileName,
        backupDate: DateTime.parse(metadataDto.backupDate),
        appVersion: metadataDto.appVersion,
        deviceInfo: metadataDto.deviceInfo,
        counts: BackupCounts(
          shopSettings: metadataDto.counts['shop_settings'] ?? 0,
          categories: metadataDto.counts['categories'] ?? 0,
          products: metadataDto.counts['products'] ?? 0,
          transactions: metadataDto.counts['transactions'] ?? 0,
          transactionItems: metadataDto.counts['transaction_items'] ?? 0,
        ),
        fileSizeBytes: lastFile.sizeInBytes,
      );

      return Right(metadata);
    } on BackupException catch (e) {
      return Left(BackupFailure(message: e.message, code: e.code));
    } on FileException catch (e) {
      return Left(FileFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DataCounts>> getCurrentDataCounts() async {
    try {
      final countsDto = await _backupService.getDataCounts();

      return Right(DataCounts(
        products: countsDto.products,
        transactions: countsDto.transactions,
        categories: countsDto.categories,
      ));
    } on BackupException catch (e) {
      return Left(BackupFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllData({
    RestoreProgressCallback? onProgress,
  }) async {
    // Clear all data is not supported in Supabase-only mode.
    return const Left(BackupFailure(
      message: 'Hapus semua data tidak didukung di mode cloud.',
      code: 'CLEAR_NOT_SUPPORTED',
    ));
  }
}
