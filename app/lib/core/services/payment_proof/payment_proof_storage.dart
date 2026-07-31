import '../image_storage/picked_image.dart';

export '../image_storage/picked_image.dart';

/// Storage for the photograph that backs a QRIS sale.
///
/// A sibling of `ImageStorageService` rather than a second implementation of
/// it, and the split is deliberate. The two look alike - pick an image,
/// compress it, put it in a bucket, get something back that renders it - but
/// they disagree on the one thing an interface has to agree on:
///
///   `ImageStorageService.publicUrlFor` is **synchronous**. It can be, because
///   `product-images` is a public bucket and the URL is pure string
///   concatenation over the object path.
///
///   [signedUrlFor] here is **asynchronous**. It has to be, because
///   `payment-proofs` is private and a signed URL is a round trip to the
///   server that can fail and does expire.
///
/// Forcing both through one interface would mean either making the product path
/// async - paying a Future, and a loading state, on every grid tile that
/// renders fine today - or pretending a signed URL is free and handing callers
/// a string that might be a stale link. Two small interfaces sharing the
/// compressor and [PickedImage] cost less than either.
///
/// Object layout: `<user_id>/<transaction_id>/<timestamp>.jpg`, matching the
/// product bucket. The leading user id is load-bearing: the bucket's RLS
/// policies read it with `storage.foldername(name)[1]` to decide who may write
/// and who may sign.
abstract class PaymentProofStorage {
  /// Compress [proof] and store it against [transactionId].
  ///
  /// Returns the object's path inside the bucket, never a URL - the host
  /// belongs to the environment, and a row that hardcodes it stops resolving
  /// the moment the same database is read from the emulator, a browser or
  /// production. `products.image_url` learned this the expensive way.
  ///
  /// Throws `ImageStorageException` on a failed compress or upload. Callers in
  /// the sale path must treat that as recoverable: the money already changed
  /// hands, so a proof that will not upload is a retry, never a failed sale.
  Future<String> upload(PickedImage proof, String transactionId);

  /// A temporary URL that renders the object at [objectPath].
  ///
  /// Minted per view rather than stored. The expiry that rules signed URLs out
  /// for product grids is harmless here: a proof is looked at when somebody
  /// opens one transaction to settle one argument, so the URL only has to
  /// outlive that screen.
  ///
  /// [validFor] defaults to an hour, comfortably longer than anyone spends on a
  /// transaction detail screen and short enough that a leaked link is worthless
  /// by the time it travels.
  Future<String> signedUrlFor(
    String objectPath, {
    Duration validFor = const Duration(hours: 1),
  });

  /// Remove the object at [objectPath].
  ///
  /// Used when a proof is replaced by a better photo. Not used for retention -
  /// nothing prunes old proofs yet.
  Future<void> delete(String objectPath);
}
