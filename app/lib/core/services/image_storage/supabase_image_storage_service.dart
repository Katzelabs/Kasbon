import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/storage_cache_control.dart';
import '../../errors/exceptions.dart';
import '../supabase_client_provider.dart';
import 'image_compressor.dart';
import 'image_storage_service.dart';

/// Product images in Supabase Storage.
///
/// The only implementation, on every platform. Its predecessor wrote to the
/// device filesystem and stored the absolute path in `products.image_url`,
/// which is why product images have never synced: the path was meaningful on
/// exactly one phone, and meaningless in a browser.
///
/// What a row holds is the object's path inside the bucket. Storing the public
/// URL instead - which this did at first - repeated the same mistake one level
/// up: the row was then only valid against the host that happened to write it,
/// so the emulator's `10.0.2.2`, a LAN address and production each invalidated
/// the others. The path is the part that is actually about the image.
///
/// Objects are laid out as `<user_id>/<product_id>/<timestamp>.<ext>`, where
/// the extension is whatever was actually encoded - `webp` from a phone, `jpg`
/// from a browser, so a shop with both has both in the bucket. The
/// leading user id is not decoration - the bucket's RLS policies read it with
/// `storage.foldername(name)[1]` to decide who may write, the same way the
/// public tables compare `user_id = auth.uid()`.
///
/// The timestamp makes each upload a new object rather than an overwrite, so a
/// replaced photo cannot be served stale from a CDN or an `Image.network`
/// cache keyed on the URL.
class SupabaseImageStorageService implements ImageStorageService {
  /// Bucket created by `20260727000001_create_product_images_bucket.sql`.
  static const String bucketName = 'product-images';

  /// The marker that separates a Supabase public URL from the object path
  /// inside it: `<project>/storage/v1/object/public/<bucket>/<path>`.
  ///
  /// Still needed after the move to storing paths: rows written before that
  /// hold a whole URL, and both reads and deletes have to keep working against
  /// them without a data migration having to have run first.
  static const String _publicUrlMarker = '/object/public/$bucketName/';

  final SupabaseClientProvider _clientProvider;

  SupabaseImageStorageService(this._clientProvider);

  StorageFileApi get _bucket => _clientProvider.client.storage.from(bucketName);

  @override
  Future<String> saveImage(PickedImage image, String productId) async {
    try {
      final userId = _clientProvider.requireUserId;
      final compressed = await compressImage(image.bytes);

      // Extension comes from what was actually encoded, not from a constant:
      // the native path produces WebP and the browser produces JPEG, so a shop
      // with two devices has both in the same bucket.
      final objectPath = '$userId/$productId/'
          '${DateTime.now().millisecondsSinceEpoch}.'
          '${compressed.fileExtension}';

      await _bucket.uploadBinary(
        objectPath,
        compressed.bytes,
        fileOptions: FileOptions(
          contentType: compressed.mimeType,
          // Every upload has a fresh timestamp, so an existing object here
          // would mean something is wrong. Failing is better than silently
          // replacing a different product's photo.
          upsert: false,
          // That same fresh timestamp is what makes a year safe: this object
          // will never be rewritten, only orphaned. See [StorageCacheControl].
          cacheControl: StorageCacheControl.maxAge,
        ),
      );

      return objectPath;
    } on ImageStorageException {
      rethrow;
    } on StorageException catch (e) {
      throw ImageStorageException(
        message: 'Gagal mengunggah gambar: ${e.message}',
        code: 'UPLOAD_FAILED',
        originalError: e,
      );
    } catch (e) {
      throw ImageStorageException(
        message: 'Gagal menyimpan gambar: ${e.toString()}',
        code: 'SAVE_FAILED',
        originalError: e,
      );
    }
  }

  @override
  String publicUrlFor(String reference) {
    final objectPath = objectPathFrom(reference);
    if (objectPath == null) return reference;

    // Note this re-derives the URL for a reference that already was one, which
    // is the point: an unmigrated row written against `127.0.0.1` renders in
    // the emulator, and against production, without being rewritten first.
    return _bucket.getPublicUrl(objectPath);
  }

  @override
  Future<void> deleteImage(String imagePath) async {
    // Legacy rows carry an absolute device path from the old local storage.
    // There is no object to remove, and nothing to report: whatever that path
    // pointed at is beyond this app's reach on every device but one.
    final objectPath = objectPathFrom(imagePath);
    if (objectPath == null) return;

    try {
      await _bucket.remove([objectPath]);
    } on StorageException catch (e) {
      throw ImageStorageException(
        message: 'Gagal menghapus gambar: ${e.message}',
        code: 'DELETE_FAILED',
        originalError: e,
      );
    } catch (e) {
      throw ImageStorageException(
        message: 'Gagal menghapus gambar: ${e.toString()}',
        code: 'DELETE_FAILED',
        originalError: e,
      );
    }
  }

  /// Whether the object behind [imagePath] is still in the bucket.
  ///
  /// A legacy device path answers false. It may well exist on the phone that
  /// created it, but this service cannot see a filesystem and must not claim
  /// otherwise - and a caller asking this question is deciding whether to
  /// fetch, which for a device path is never the right answer.
  @override
  Future<bool> imageExists(String imagePath) async {
    final objectPath = objectPathFrom(imagePath);
    if (objectPath == null) return false;

    try {
      final lastSlash = objectPath.lastIndexOf('/');
      final directory = objectPath.substring(0, lastSlash);
      final fileName = objectPath.substring(lastSlash + 1);

      final entries = await _bucket.list(path: directory);

      return entries.any((entry) => entry.name == fileName);
    } catch (e) {
      return false;
    }
  }

  /// The object path inside the bucket for a stored [reference], or null when
  /// the reference is not one of ours.
  ///
  /// Takes either shape a row can hold - a bare object path, or a full public
  /// URL from before those were stored - and normalises to the path. Null
  /// covers legacy device paths and any other URL, which is the same answer for
  /// callers: this service has nothing to do with it.
  ///
  /// Visible for testing - the round trip through `getPublicUrl` and back is
  /// the one piece of string handling here that can silently rot if Supabase
  /// ever changes its URL shape.
  static String? objectPathFrom(String reference) {
    final markerAt = reference.indexOf(_publicUrlMarker);

    final String path;
    if (markerAt != -1) {
      path = reference.substring(markerAt + _publicUrlMarker.length);
    } else if (reference.contains('://') || reference.startsWith('/')) {
      // A URL that is not ours - another bucket, another host - or an absolute
      // device path from the retired local storage. Neither names an object
      // here, and guessing would mean deleting against a path we invented.
      return null;
    } else {
      path = reference;
    }

    // A trailing `?` query (cache busting, image transforms) is not part of
    // the object name.
    final queryAt = path.indexOf('?');
    final objectPath = queryAt == -1 ? path : path.substring(0, queryAt);

    return objectPath.isEmpty || !objectPath.contains('/') ? null : objectPath;
  }
}
