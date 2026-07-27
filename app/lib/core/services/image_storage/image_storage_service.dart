import 'picked_image.dart';

export 'picked_image.dart';

/// Abstract interface for image storage operations.
/// Allows for different implementations (local, cloud) for future flexibility.
///
/// Deliberately free of `dart:io`. The previous signature took a `File`, which
/// forced that import onto every caller and is the single reason the product
/// feature could not build for web. [PickedImage] carries bytes instead, which
/// the picker produces identically on native and in a browser.
///
/// One implementation, [SupabaseImageStorageService], on every platform.
/// Rows created before it landed still carry an absolute device path, so
/// callers must cope with both shapes on read.
abstract class ImageStorageService {
  /// Save an image and return the reference stored in `products.image_url`.
  ///
  /// [image] - The picked image data
  /// [productId] - The product ID to associate with the image
  ///
  /// Returns an https URL. Callers must treat the result as opaque and never
  /// parse it.
  Future<String> saveImage(PickedImage image, String productId);

  /// Delete an image from storage.
  ///
  /// [imagePath] - The path of the image to delete
  Future<void> deleteImage(String imagePath);

  /// Check if an image exists at the given path.
  ///
  /// [imagePath] - The path to check
  /// Returns true if the image exists
  Future<bool> imageExists(String imagePath);
}
