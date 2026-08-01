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
/// ## The format is read back off the bytes, never assumed from the request
///
/// Asking for WebP is not the same as getting it, and the difference is silent.
/// On macOS `getOutputFormat()` in `flutter_image_compress_macos` maps WebP to
/// its `default:` branch - `kUTTypeJPEG` - so the call succeeds, returns a
/// perfectly good JPEG, and reports nothing. Trusting the request there stores
/// JPEG bytes named `.webp` under `image/webp`, which nothing notices until
/// something strict tries to decode one.
///
/// iOS does honour it (`format == 3` goes to `SDImageWebPCoder`), and Android
/// uses the system encoder. But the point is not to keep a list of which
/// platforms are honest: sniffing the result is two comparisons, and it is
/// correct on platforms nobody has tried yet.
Future<CompressedImage> compressImage(
  Uint8List bytes, {
  int maxDimension = ImageCompression.maxDimension,
  int quality = ImageCompression.quality,
}) async {
  // WebP first, because it is about half the size when the platform can do it.
  final webp = await _tryCompress(
    bytes,
    maxDimension: maxDimension,
    quality: quality,
    format: CompressFormat.webp,
  );

  // A JPEG here means the platform quietly substituted one (macOS). Keep it -
  // it is the same compressed image the JPEG branch would produce, so asking
  // again would only spend the work twice.
  final asked = webp == null ? null : _sniff(webp);
  if (asked != null) {
    return CompressedImage(bytes: webp!, format: asked);
  }

  final jpeg = await _tryCompress(
    bytes,
    maxDimension: maxDimension,
    quality: quality,
    format: CompressFormat.jpeg,
  );
  final fallback = jpeg == null ? null : _sniff(jpeg);
  if (fallback != null) {
    return CompressedImage(bytes: jpeg!, format: fallback);
  }

  // Both codecs refused, or returned something neither this app nor the buckets
  // accept. Uploading the original instead would put an uncompressed camera
  // file in a bucket with a 5 MiB ceiling.
  throw const ImageStorageException(
    message: 'Gagal mengompres gambar',
    code: 'COMPRESSION_FAILED',
  );
}

/// What [bytes] actually are, or null if it is not a format either bucket takes.
///
/// Deliberately narrow. PNG would decode fine and both buckets allow it, but
/// nothing here ever asks for one, so a PNG coming back means the plugin did
/// something unexpected - and falling through to the JPEG attempt is a better
/// answer than storing a surprise.
ImageFormat? _sniff(Uint8List bytes) {
  // SOI + the marker byte that follows it in every JPEG.
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return ImageFormat.jpeg;
  }

  // 'RIFF' .... 'WEBP' - the four size bytes in between are skipped.
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return ImageFormat.webp;
  }

  return null;
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
