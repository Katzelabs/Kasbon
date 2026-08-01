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

  /// Encoder quality, 1-100.
  ///
  /// Means the same thing to both encoders in the sense that matters: the
  /// measurements behind the move to WebP compared the two formats at the *same*
  /// number, so this did not need retuning when the format changed.
  static const int quality = 75;

  // `mimeType` and `fileExtension` used to live here as constants, on the
  // reasonable assumption that everything was JPEG everywhere. The native path
  // now produces WebP and the browser still cannot, so the format is a property
  // of one compression rather than of the app, and it travels with the bytes -
  // see `CompressedImage`.
  //
  // Deleted rather than left pointing at JPEG: a caller reading a constant
  // while holding WebP bytes names the object `.jpg`, and nothing notices until
  // a browser declines to render it.
}
