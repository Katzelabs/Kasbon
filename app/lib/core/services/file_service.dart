import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../errors/exceptions.dart';

/// Static utility class for file operations related to backup/restore
class FileService {
  FileService._();

  static const String _backupFolderName = 'backups';
  static const String _backupPrefix = 'kasbon_backup_';
  static const String _backupExtension = '.json';

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
          final downloadsPath = path.join(rootPath, 'Download', 'KASBON_Backup');
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
        final internalBackupDir = Directory(path.join(appDocDir.path, _backupFolderName));
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

  /// Writes JSON content to a file and returns the file path
  /// If [directory] is provided, saves to that directory instead of the default
  static Future<String> saveBackupFile(
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
      final file = File(filePath);

      await file.writeAsString(content);

      return filePath;
    } catch (e) {
      if (e is FileException) rethrow;
      throw FileException(
        message: 'Gagal menyimpan file backup',
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

  /// Returns the most recent backup file, or null if no backups exist
  static Future<File?> getLastBackupFile() async {
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

      return files.first;
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
