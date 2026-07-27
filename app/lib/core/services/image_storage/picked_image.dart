import 'dart:typed_data';

/// An image the user selected, carried as bytes.
///
/// Bytes rather than a path, because `XFile.path` is not portable: on native it
/// is a real filesystem path, but on web it is a `blob:` URL that no file API
/// can open. `XFile.readAsBytes()` behaves identically on both, which is what
/// lets one [ImageStorageService] interface serve every platform.
///
/// This is also what removes `dart:io` from the product feature. The `File` in
/// the old `saveImage` signature forced the import onto every caller, which is
/// why four widgets carried it.
class PickedImage {
  /// Raw, uncompressed image data as returned by the picker.
  final Uint8List bytes;

  /// Original filename, when the picker supplies one.
  ///
  /// Advisory only - storage decides the real name. Useful for reading the
  /// source extension when deciding how to decode.
  final String? name;

  const PickedImage({required this.bytes, this.name});

  int get sizeInBytes => bytes.length;
}
