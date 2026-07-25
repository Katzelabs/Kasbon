import 'dart:io';

/// Abstract interface for image storage operations.
/// Allows for different implementations (local, cloud) for future flexibility.
abstract class ImageStorageService {
  /// Save an image file and return the storage path.
  ///
  /// [imageFile] - The image file to save
  /// [productId] - The product ID to associate with the image
  /// Returns the path where the image was saved
  Future<String> saveImage(File imageFile, String productId);

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
