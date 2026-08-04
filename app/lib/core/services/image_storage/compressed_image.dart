import 'dart:typed_data';

/// A format the app is willing to store.
///
/// Both buckets allow all of these already - see the `allowed_mime_types` in
/// `20260804010006_storage_buckets.sql`, which listed webp from the start
/// precisely so switching to it would not need a migration.
///
/// `image/svg+xml` is deliberately absent, there and here: SVG is a document
/// format that can carry script, and `product-images` is public.
enum ImageFormat {
  jpeg('image/jpeg', 'jpg'),
  webp('image/webp', 'webp');

  const ImageFormat(this.mimeType, this.fileExtension);

  /// Content type the object is stored with.
  final String mimeType;

  /// Extension matching [mimeType]. Part of the object path, so it is also what
  /// a later read has to agree about.
  final String fileExtension;
}

/// Compressed bytes together with what they actually are.
///
/// The compressor used to return a bare `Uint8List` and the format was a
/// constant, because everything was JPEG on every platform. It is not any more:
/// the native encoders produce WebP, and the browser cannot, so the format is a
/// property of a particular compression rather than of the app.
///
/// Keeping them together is the point. The alternative - returning bytes and
/// having the caller consult a constant for the extension - is how an object
/// ends up named `.jpg` while holding WebP, which nothing would notice until a
/// browser refused to render it.
class CompressedImage {
  const CompressedImage({required this.bytes, required this.format});

  final Uint8List bytes;
  final ImageFormat format;

  /// Convenience for the storage services, which need both.
  String get mimeType => format.mimeType;
  String get fileExtension => format.fileExtension;
}
