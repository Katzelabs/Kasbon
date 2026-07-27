/// The one place the compression numbers live.
///
/// Shared by the native and browser compressors so the two cannot drift: a
/// product photo taken on a phone and the same photo uploaded from a laptop
/// should end up the same size in the bucket.
class ImageCompression {
  ImageCompression._();

  /// Longest side a stored product image is allowed to keep, in pixels.
  ///
  /// 800 is comfortably above the largest place a product image is drawn (a
  /// grid tile on a 2560px monitor) and small enough that a photo costs a shop
  /// owner well under 100 KB of mobile data to upload.
  static const int maxDimension = 800;

  /// JPEG quality, 1-100.
  static const int quality = 75;

  /// Content type every compressed image is stored as.
  static const String mimeType = 'image/jpeg';

  /// Extension matching [mimeType].
  static const String fileExtension = 'jpg';
}
