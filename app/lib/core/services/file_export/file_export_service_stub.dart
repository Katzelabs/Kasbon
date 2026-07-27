import 'dart:typed_data';

import 'file_export_types.dart';

/// Fallback for platforms with neither `dart:io` nor JS interop.
///
/// Unreachable in practice; it exists because a conditional export needs a
/// default. Every member throws rather than returning a plausible value, so a
/// build that somehow resolved here fails loudly instead of silently
/// pretending files were written.
class FileExportService {
  FileExportService._();

  static bool get hasAddressableFiles =>
      throw UnsupportedError('No file export implementation for this platform');

  static Future<String> getBackupDirectory() async =>
      throw UnsupportedError('No file export implementation for this platform');

  static Future<SavedFile> saveText(
    String content,
    String filename, {
    String? directory,
  }) async =>
      throw UnsupportedError('No file export implementation for this platform');

  static Future<SavedFile> saveBytes(
    Uint8List bytes,
    String filename, {
    String? directory,
  }) async =>
      throw UnsupportedError('No file export implementation for this platform');

  static Future<String> readFile(String filePath) async =>
      throw UnsupportedError('No file export implementation for this platform');

  static String generateBackupFilename() =>
      throw UnsupportedError('No file export implementation for this platform');

  static Future<BackupFileRef?> findLastBackup() async =>
      throw UnsupportedError('No file export implementation for this platform');

  static Future<int> getFileSize(String filePath) async =>
      throw UnsupportedError('No file export implementation for this platform');

  static String formatFileSize(int bytes) =>
      throw UnsupportedError('No file export implementation for this platform');

  static String getFileName(String filePath) =>
      throw UnsupportedError('No file export implementation for this platform');

  static Future<void> deleteBackupFile(String filePath) async =>
      throw UnsupportedError('No file export implementation for this platform');
}
