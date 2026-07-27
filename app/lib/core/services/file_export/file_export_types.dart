/// Platform-neutral types shared by the io and web file-export
/// implementations.
///
/// Deliberately free of `dart:io`: these cross the conditional-import boundary,
/// so a `File` here would defeat the whole arrangement.
library;

/// A file the app has written.
///
/// [path] is null when the platform has no filesystem the app can address - on
/// web an export is a browser download, and the app is never told where it
/// landed. Callers must treat a null path as "saved, location unknown" rather
/// than as failure, and must not build a share intent from it.
class SavedFile {
  final String? path;
  final String fileName;

  const SavedFile({required this.fileName, this.path});

  /// Whether there is a real filesystem location to show or share.
  bool get hasPath => path != null;
}

/// A reference to a previously written backup file.
///
/// Replaces the `dart:io` `File` the old `FileService.getLastBackupFile`
/// returned. Callers only ever needed the path, the name and the size.
class BackupFileRef {
  final String path;
  final String fileName;
  final int sizeInBytes;
  final DateTime modified;

  const BackupFileRef({
    required this.path,
    required this.fileName,
    required this.sizeInBytes,
    required this.modified,
  });
}
