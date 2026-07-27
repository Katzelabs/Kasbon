import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../errors/exceptions.dart';
import 'file_export_types.dart';

/// Native file export: writes to the device filesystem.
///
/// Behaviourally identical to the `FileService` this replaced. The only API
/// change is that nothing `dart:io`-typed escapes - `findLastBackup` returns a
/// [BackupFileRef] where it used to return a `File`.
class FileExportService {
  FileExportService._();

  static const String _backupFolderName = 'backups';
  static const String _backupPrefix = 'kasbon_backup_';
  static const String _backupExtension = '.json';

  /// Whether saved files have a path worth showing the user.
  static bool get hasAddressableFiles => true;

  /// Returns/creates the backup directory path
  /// Saves to external storage on Android for easy access via file manager
  static Future<String> getBackupDirectory() async {
    try {
      Directory? backupDir;

      // Try to use external storage first (visible in file managers)
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Go up to Android folder level and create KASBON_Backup in root
          // externalDir is typically /storage/emulated/0/Android/data/com.app/files
          final rootPath = externalDir.path.split('Android').first;
          final downloadsPath =
              path.join(rootPath, 'Download', 'KASBON_Backup');
          backupDir = Directory(downloadsPath);
        }
      }

      // Fallback to app documents directory
      backupDir ??= Directory(path.join(
        (await getApplicationDocumentsDirectory()).path,
        _backupFolderName,
      ));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      return backupDir.path;
    } catch (e) {
      // If external storage fails, use internal storage
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final internalBackupDir =
            Directory(path.join(appDocDir.path, _backupFolderName));
        if (!await internalBackupDir.exists()) {
          await internalBackupDir.create(recursive: true);
        }
        return internalBackupDir.path;
      } catch (_) {
        throw FileException(
          message: 'Gagal mengakses direktori backup',
          originalError: e,
        );
      }
    }
  }

  /// Writes JSON content to a file.
  ///
  /// If [directory] is provided, saves there instead of the default.
  static Future<SavedFile> saveText(
    String content,
    String filename, {
    String? directory,
  }) async {
    try {
      final backupDir = directory ?? await getBackupDirectory();

      // Ensure directory exists if custom directory is provided
      if (directory != null) {
        final dir = Directory(backupDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      final filePath = path.join(backupDir, filename);
      await File(filePath).writeAsString(content);

      return SavedFile(path: filePath, fileName: filename);
    } catch (e) {
      if (e is FileException) rethrow;
      throw FileException(
        message: 'Gagal menyimpan file backup',
        originalError: e,
      );
    }
  }

  /// Writes binary content to a file.
  ///
  /// The string-based [saveText] cannot be reused for exports: .xlsx and .pdf
  /// are binary formats, and round-tripping their bytes through a Dart String
  /// would corrupt them.
  ///
  /// Saves alongside the backups by default so exports land somewhere the user
  /// can find with a file manager.
  static Future<SavedFile> saveBytes(
    Uint8List bytes,
    String filename, {
    String? directory,
  }) async {
    try {
      final targetDir = directory ?? await getBackupDirectory();

      if (directory != null) {
        final dir = Directory(targetDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      final filePath = path.join(targetDir, filename);
      await File(filePath).writeAsBytes(bytes, flush: true);

      return SavedFile(path: filePath, fileName: filename);
    } catch (e) {
      if (e is FileException) rethrow;
      throw FileException(
        message: 'Gagal menyimpan file ekspor',
        originalError: e,
      );
    }
  }

  /// Reads file content from a given path
  static Future<String> readFile(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw const FileException(
          message: 'File tidak ditemukan',
          code: 'FILE_NOT_FOUND',
        );
      }

      return await file.readAsString();
    } catch (e) {
      if (e is FileException) rethrow;
      throw FileException(
        message: 'Gagal membaca file',
        originalError: e,
      );
    }
  }

  /// Generates a backup filename with timestamp
  /// Format: kasbon_backup_YYYYMMDD_HHmmss.json
  static String generateBackupFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    return '$_backupPrefix${formatter.format(now)}$_backupExtension';
  }

  /// Returns the most recent backup file, or null if no backups exist.
  static Future<BackupFileRef?> findLastBackup() async {
    try {
      final backupDir = await getBackupDirectory();
      final directory = Directory(backupDir);

      if (!await directory.exists()) {
        return null;
      }

      final files = await directory
          .list()
          .where((entity) =>
              entity is File &&
              entity.path.contains(_backupPrefix) &&
              entity.path.endsWith(_backupExtension))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        return null;
      }

      // Sort by modification time, most recent first
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      final newest = files.first;
      final stat = newest.statSync();

      return BackupFileRef(
        path: newest.path,
        fileName: path.basename(newest.path),
        sizeInBytes: stat.size,
        modified: stat.modified,
      );
    } catch (e) {
      // If we can't get the last backup, just return null
      return null;
    }
  }

  /// Gets the file size in bytes
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 0;
      }
      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      return 0;
    }
  }

  /// Formats file size for display (KB, MB)
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
      return '$mb MB';
    }
  }

  /// Extracts filename from a file path
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Deletes a backup file
  static Future<void> deleteBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw FileException(
        message: 'Gagal menghapus file backup',
        originalError: e,
      );
    }
  }
}
