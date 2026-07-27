import 'dart:typed_data';

/// A generated export file, held in memory before it is saved or shared.
///
/// The exporters are deliberately pure: they turn domain objects into bytes and
/// nothing else. Saving and sharing are the caller's job, which keeps them
/// testable without touching the filesystem or a share sheet.
class ExportResult {
  /// The encoded file contents.
  final Uint8List bytes;

  /// Suggested filename, including extension.
  final String fileName;

  /// MIME type, used by the share sheet to pick a target app.
  final String mimeType;

  /// Rows that were dropped because the export hit its cap, or zero.
  ///
  /// Surfaced so the UI can say the export is partial. A silently truncated
  /// report reads as a complete one, which is worse than a slow export.
  final int omittedRowCount;

  const ExportResult({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    this.omittedRowCount = 0,
  });

  bool get isTruncated => omittedRowCount > 0;

  int get sizeInBytes => bytes.length;

  static const String xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static const String pdfMimeType = 'application/pdf';
}
