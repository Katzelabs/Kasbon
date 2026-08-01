import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/storage_cache_control.dart';
import '../../errors/exceptions.dart';
import '../image_storage/image_compressor.dart';
import '../supabase_client_provider.dart';
import 'payment_proof_compression.dart';
import 'payment_proof_storage.dart';

/// Payment proofs in the private `payment-proofs` bucket.
///
/// Reuses the product feature's compressor - the work is identical, only the
/// numbers differ (see [PaymentProofCompression]) - and shares nothing else
/// with `SupabaseImageStorageService`.
///
/// Notably absent: any equivalent of that class's `objectPathFrom`. It exists
/// there to cope with rows written before object paths were stored, which hold
/// a full public URL or a legacy device path. This column is new, so every
/// value in it is an object path written by [upload]. Accepting anything else
/// would mean inventing a shape to be backwards compatible with.
class SupabasePaymentProofStorage implements PaymentProofStorage {
  /// Bucket created by `20260731000002_create_payment_proofs_bucket.sql`.
  static const String bucketName = 'payment-proofs';

  final SupabaseClientProvider _clientProvider;

  SupabasePaymentProofStorage(this._clientProvider);

  StorageFileApi get _bucket => _clientProvider.client.storage.from(bucketName);

  @override
  Future<String> upload(PickedImage proof, String transactionId) async {
    try {
      final userId = _clientProvider.requireUserId;

      final compressed = await compressImage(
        proof.bytes,
        maxDimension: PaymentProofCompression.maxDimension,
        quality: PaymentProofCompression.quality,
      );

      final objectPath = '$userId/$transactionId/'
          '${DateTime.now().millisecondsSinceEpoch}.'
          '${PaymentProofCompression.fileExtension}';

      await _bucket.uploadBinary(
        objectPath,
        compressed,
        fileOptions: const FileOptions(
          contentType: PaymentProofCompression.mimeType,
          // A fresh timestamp per upload means a collision here would mean
          // something is wrong. Re-shooting a proof writes a new object and
          // leaves the old one for [delete] to remove, so that the row never
          // points at a half-overwritten file.
          upsert: false,
          // Correct, but worth far less here than on the public bucket: this
          // one is read through signed URLs, and a fresh signature is minted
          // per view, so the URL a cache would key on rarely repeats. It earns
          // its keep within a single view and costs nothing. The thing that
          // actually bounds this bucket is retention, not caching.
          cacheControl: StorageCacheControl.maxAge,
        ),
      );

      return objectPath;
    } on ImageStorageException {
      rethrow;
    } on StorageException catch (e) {
      throw ImageStorageException(
        message: 'Gagal mengunggah bukti pembayaran: ${e.message}',
        code: 'PROOF_UPLOAD_FAILED',
        originalError: e,
      );
    } catch (e) {
      throw ImageStorageException(
        message: 'Gagal menyimpan bukti pembayaran: ${e.toString()}',
        code: 'PROOF_SAVE_FAILED',
        originalError: e,
      );
    }
  }

  @override
  Future<String> signedUrlFor(
    String objectPath, {
    Duration validFor = const Duration(hours: 1),
  }) async {
    try {
      return await _bucket.createSignedUrl(objectPath, validFor.inSeconds);
    } on StorageException catch (e) {
      throw ImageStorageException(
        message: 'Gagal membuka bukti pembayaran: ${e.message}',
        code: 'PROOF_URL_FAILED',
        originalError: e,
      );
    } catch (e) {
      throw ImageStorageException(
        message: 'Gagal membuka bukti pembayaran: ${e.toString()}',
        code: 'PROOF_URL_FAILED',
        originalError: e,
      );
    }
  }

  @override
  Future<void> delete(String objectPath) async {
    try {
      await _bucket.remove([objectPath]);
    } on StorageException catch (e) {
      throw ImageStorageException(
        message: 'Gagal menghapus bukti pembayaran: ${e.message}',
        code: 'PROOF_DELETE_FAILED',
        originalError: e,
      );
    } catch (e) {
      throw ImageStorageException(
        message: 'Gagal menghapus bukti pembayaran: ${e.toString()}',
        code: 'PROOF_DELETE_FAILED',
        originalError: e,
      );
    }
  }
}
