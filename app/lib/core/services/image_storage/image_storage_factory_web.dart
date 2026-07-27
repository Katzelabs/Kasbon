import '../../errors/exceptions.dart';
import 'image_storage_service.dart';

/// Web has no local filesystem to store product images in.
///
/// This is a placeholder until RESP_02 introduces the Supabase Storage
/// implementation, which serves every platform and is the real fix. Until then
/// the browser build runs, browses and sells - it just cannot attach a photo to
/// a product.
///
/// Every method throws with a message a shop owner can read rather than failing
/// silently, so an unfinished path cannot be mistaken for a working one.
ImageStorageService createImageStorageService() =>
    const _UnsupportedImageStorageService();

class _UnsupportedImageStorageService implements ImageStorageService {
  const _UnsupportedImageStorageService();

  static const _unsupported = ImageStorageException(
    message: 'Unggah foto produk belum tersedia di browser',
    code: 'IMAGE_UPLOAD_NOT_SUPPORTED_ON_WEB',
  );

  @override
  Future<String> saveImage(PickedImage image, String productId) async =>
      throw _unsupported;

  @override
  Future<void> deleteImage(String imagePath) async => throw _unsupported;

  /// False rather than a throw: this is a question, and "no" is a truthful
  /// answer for a browser that cannot see the device filesystem. Throwing
  /// would break callers that legitimately ask before rendering.
  @override
  Future<bool> imageExists(String imagePath) async => false;
}
