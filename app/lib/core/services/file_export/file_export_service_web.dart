import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../errors/exceptions.dart';
import 'file_export_types.dart';

/// Web file export.
///
/// **Incomplete by design.** RESP_01 exists to make the app compile and run in
/// Chrome; RESP_02 implements the actual browser download (Blob + anchor via
/// `package:web`) and makes backup and report export work here.
///
/// Every unimplemented method throws [FileException] with a message a shop
/// owner can read, rather than returning a fake success. A silent no-op would
/// show "Tersimpan" for a file that does not exist, which is worse than the
/// feature being visibly unavailable.
class FileExportService {
  FileExportService._();

  static const String _backupPrefix = 'kasbon_backup_';
  static const String _backupExtension = '.json';

  /// A browser download gives the app no path back, so nothing on web has an
  /// address to show or share.
  static bool get hasAddressableFiles => false;

  static const _unsupported = FileException(
    message: 'Ekspor berkas belum tersedia di browser',
    code: 'EXPORT_NOT_SUPPORTED_ON_WEB',
  );

  /// There is no directory to choose in a browser - the user's download
  /// settings decide where files land.
  static Future<String> getBackupDirectory() async => throw _unsupported;

  static Future<SavedFile> saveText(
    String content,
    String filename, {
    String? directory,
  }) async =>
      throw _unsupported;

  static Future<SavedFile> saveBytes(
    Uint8List bytes,
    String filename, {
    String? directory,
  }) async =>
      throw _unsupported;

  /// Reading back a downloaded file is not possible: the browser never tells
  /// the app where it went. Restoring from a file on web goes through
  /// `file_picker` instead, and `restoreBackup` is unsupported on every
  /// platform anyway.
  static Future<String> readFile(String filePath) async => throw _unsupported;

  /// Filename generation is pure string work, so it behaves identically here.
  static String generateBackupFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    return '$_backupPrefix${formatter.format(now)}$_backupExtension';
  }

  /// The app cannot see the browser's download folder, so there is no "last
  /// backup" to report. Null rather than a throw: callers treat this as
  /// "nothing yet", which is accurate.
  static Future<BackupFileRef?> findLastBackup() async => null;

  static Future<int> getFileSize(String filePath) async => 0;

  /// Pure string formatting - identical to the io implementation.
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

  /// Deliberately not `package:path`'s `basename`: this takes a browser-style
  /// name that may carry either separator, and must not depend on the host
  /// path style.
  static String getFileName(String filePath) {
    final normalised = filePath.replaceAll('\\', '/');
    final lastSlash = normalised.lastIndexOf('/');
    return lastSlash == -1 ? normalised : normalised.substring(lastSlash + 1);
  }

  static Future<void> deleteBackupFile(String filePath) async =>
      throw _unsupported;
}
