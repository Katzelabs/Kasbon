import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../errors/exceptions.dart';
import 'image_storage_service.dart';

/// Local file system implementation of [ImageStorageService].
/// Stores compressed images in the app's documents directory.
class LocalImageStorageService implements ImageStorageService {
  /// Maximum dimension (width or height) for compressed images
  static const int _maxDimension = 800;

  /// JPEG quality (1-100)
  static const int _quality = 75;

  /// Subdirectory name for product images
  static const String _imageDirectory = 'product_images';

  /// Get the directory for storing product images
  Future<Directory> _getImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, _imageDirectory));

    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    return imageDir;
  }

  @override
  Future<String> saveImage(File imageFile, String productId) async {
    try {
      final imageDir = await _getImageDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'prod_${productId}_$timestamp.jpg';
      final targetPath = p.join(imageDir.path, filename);

      // Compress and save the image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: _quality,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        throw const ImageStorageException(
          message: 'Gagal mengompres gambar',
          code: 'COMPRESSION_FAILED',
        );
      }

      return compressedFile.path;
    } catch (e) {
      if (e is ImageStorageException) rethrow;

      throw ImageStorageException(
        message: 'Gagal menyimpan gambar: ${e.toString()}',
        code: 'SAVE_FAILED',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw ImageStorageException(
        message: 'Gagal menghapus gambar: ${e.toString()}',
        code: 'DELETE_FAILED',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> imageExists(String imagePath) async {
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
