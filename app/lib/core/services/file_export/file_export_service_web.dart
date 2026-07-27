import 'dart:js_interop';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../../errors/exceptions.dart';
import 'file_export_types.dart';

/// Web file export: hands bytes to the browser as a download.
///
/// A browser will not let a page write to a path, so "export" here means
/// building an in-memory Blob and clicking a synthetic link at it. The file
/// lands wherever the user's download settings say, and the app is never told
/// where that is - which is why [hasAddressableFiles] is false and every
/// [SavedFile] returned from here carries a null path.
///
/// The methods that read files back stay unsupported. That is not an omission:
/// there is nothing to read. The app cannot see the download folder, and
/// restoring from a file goes through `file_picker` instead.
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

  /// Downloads [content] as a text file.
  ///
  /// [directory] is accepted and ignored: the browser owns that decision. The
  /// parameter stays so the io and web implementations remain interchangeable,
  /// and callers avoid asking the user for a folder by checking
  /// [hasAddressableFiles] first.
  static Future<SavedFile> saveText(
    String content,
    String filename, {
    String? directory,
  }) async {
    _download(content.toJS, filename, _mimeTypeFor(filename));

    return SavedFile(fileName: filename);
  }

  /// Downloads [bytes] as a file.
  ///
  /// Used by report export for .xlsx and .pdf, both of which are binary and
  /// would be corrupted by a round trip through a Dart String.
  static Future<SavedFile> saveBytes(
    Uint8List bytes,
    String filename, {
    String? directory,
  }) async {
    _download(bytes.toJS, filename, _mimeTypeFor(filename));

    return SavedFile(fileName: filename);
  }

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

  /// Wraps [part] in a Blob and clicks a hidden link at it.
  ///
  /// The anchor is appended to the document rather than clicked detached:
  /// Firefox ignores a click on an element that is not in the tree.
  static void _download(JSAny part, String filename, String mimeType) {
    final blob = web.Blob(
      <JSAny>[part].toJS,
      web.BlobPropertyBag(type: mimeType),
    );

    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename
      ..style.display = 'none';

    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();

    // Revoked on a later turn of the event loop. `click()` only *starts* the
    // download; revoking in the same turn races the browser fetching the blob,
    // and a lost export is worse than holding a few megabytes a moment longer.
    Future<void>.delayed(
      const Duration(seconds: 1),
      () => web.URL.revokeObjectURL(url),
    );
  }

  /// Content type from the extension the exporter chose.
  ///
  /// Worth getting right: the browser uses it to decide whether it can preview
  /// the download, and `application/octet-stream` turns a report into an
  /// anonymous blob the user has to guess at.
  static String _mimeTypeFor(String filename) {
    final lower = filename.toLowerCase();

    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.json')) return 'application/json;charset=utf-8';
    if (lower.endsWith('.csv')) return 'text/csv;charset=utf-8';

    return 'application/octet-stream';
  }
}
