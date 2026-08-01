import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../errors/exceptions.dart';
import 'compressed_image.dart';
import 'image_compression_settings.dart';

/// Native compression, handed to the platform's own image codecs.
///
/// `compressWithList` rather than `compressAndGetFile`: the picker gives us
/// bytes and storage takes bytes, so the file-path variant would mean writing
/// the original to disk purely to give the compressor something to open.
///
/// [maxDimension] is passed as both `minWidth` and `minHeight`, which is how
/// this plugin expresses "scale down until the *shorter* side reaches this,
/// keeping aspect ratio". A 4000x3000 photo comes back 1067x800.
///
/// ## WebP, with JPEG behind it
///
/// Measured on representative content at matched quality, WebP is about half
/// the size of JPEG - 54% smaller on a photograph at 800px, and 51% on a
/// screenshot of a phone at 1000px, which is what a payment proof is. That is
/// the largest single reduction available to either bucket, and it needs no
/// migration: both were created allowing `image/webp`.
///
/// (A synthetic image of random per-pixel grain shows almost no gain, which is
/// a property of the test image rather than the format - noise defeats WebP's
/// predictor. Real photographs and screenshots are not noise.)
///
/// It is attempted rather than assumed because platform support is uneven.
/// Android uses the system encoder and is fast; iOS goes through
/// SDWebImageWebPCoder, which the plugin documents as working but noticeably
/// slower. Neither is guaranteed on every device. A shop owner who cannot save
/// a product photo has a far worse problem than one whose photo is larger than
/// it needed to be, so a failure here falls back instead of propagating.
Future<CompressedImage> compressImage(
  Uint8List bytes, {
  int maxDimension = ImageCompression.maxDimension,
  int quality = ImageCompression.quality,
}) async {
  final webp = await _tryCompress(
    bytes,
    maxDimension: maxDimension,
    quality: quality,
    format: CompressFormat.webp,
  );
  if (webp != null) {
    return CompressedImage(bytes: webp, format: ImageFormat.webp);
  }

  final jpeg = await _tryCompress(
    bytes,
    maxDimension: maxDimension,
    quality: quality,
    format: CompressFormat.jpeg,
  );
  if (jpeg != null) {
    return CompressedImage(bytes: jpeg, format: ImageFormat.jpeg);
  }

  // Both codecs refused, so these bytes are not an image this device can read.
  // Uploading the original instead would put an uncompressed camera file in a
  // bucket with a 5 MiB ceiling.
  throw const ImageStorageException(
    message: 'Gagal mengompres gambar',
    code: 'COMPRESSION_FAILED',
  );
}

/// One encode attempt, or null if this device cannot do it.
///
/// Catches rather than checks: the plugin reports a missing encoder as a thrown
/// error on some platforms and an empty list on others, and both mean the same
/// thing here.
Future<Uint8List?> _tryCompress(
  Uint8List bytes, {
  required int maxDimension,
  required int quality,
  required CompressFormat format,
}) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: format,
    );
    return result.isEmpty ? null : result;
  } catch (_) {
    return null;
  }
}
