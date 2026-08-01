import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../errors/exceptions.dart';
import 'image_compression_settings.dart';

/// Pure-Dart compression: decode, resize, re-encode as JPEG.
///
/// Lives in its own file rather than inside `image_compressor_web.dart`
/// because there is nothing browser-specific about it. Keeping it platform
/// neutral means the resize arithmetic - the part with an off-by-one to get
/// wrong - is covered by an ordinary VM test.
///
/// Slower than the native path, and on web it runs on the only thread there
/// is: `compute` does not fork an isolate in a browser. Acceptable because it
/// happens once per photo, behind the picker's existing loading state, and the
/// alternative is uploading the original.
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int maxDimension = ImageCompression.maxDimension,
  int quality = ImageCompression.quality,
}) async {
  // `decodeImage` returns null for a format it does not recognise, but throws
  // for one it half-recognises: a truncated or corrupt file sends a decoder
  // reading past the end of the buffer. Both mean the same thing to the user,
  // and neither should reach the picker as a raw RangeError.
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (e) {
    throw ImageStorageException(
      message: 'Format gambar tidak dikenali',
      code: 'DECODE_FAILED',
      originalError: e,
    );
  }

  if (decoded == null) {
    throw const ImageStorageException(
      message: 'Format gambar tidak dikenali',
      code: 'DECODE_FAILED',
    );
  }

  // Orientation has to reach the pixels before the Exif block is dropped, or a
  // portrait photo comes back sideways. `copyResize` bakes it itself - but only
  // when it actually resizes, and `_fit` returns the source untouched for an
  // image already under the maximum. That is the path where dropping Exif
  // silently rotated things, so the baking happens here instead of being left
  // to the resize.
  //
  // Guarded rather than called unconditionally because `bakeOrientation` copies
  // the whole image before it checks, and the common case - orientation 1, or
  // no Exif at all - would pay a full-frame allocation for nothing. On web that
  // runs on the only thread there is.
  final oriented = decoded.exif.imageIfd.hasOrientation &&
          decoded.exif.imageIfd.orientation != 1
      ? img.bakeOrientation(decoded)
      : decoded;

  final fitted = _fit(oriented, maxDimension);

  // Drop Exif, matching the native compressor's `keepExif: false` default.
  //
  // `decodeImage` populates `exif`, `Image.from` clones it and `encodeJpg`
  // writes it back out, so without this the browser path forwards the camera's
  // entire Exif block - including the embedded thumbnail, routinely 10-30 KB
  // against a 1 GB storage quota, and `gpsIfd`, which is the coordinates the
  // photo was taken at. `product-images` is a public bucket.
  fitted.exif = img.ExifData();

  // 4:2:0 chroma subsampling, which is what phone cameras and the platform
  // encoders behind `flutter_image_compress` produce. `encodeJpg` defaults to
  // yuv444 - full-resolution colour - which costs 15-20% more bytes for a
  // difference invisible in a photograph.
  //
  // Without it the same photo landed measurably larger from a browser than from
  // a phone, which is the drift the shared settings exist to prevent.
  return img.encodeJpg(
    fitted,
    quality: quality,
    chroma: img.JpegChroma.yuv420,
  );
}

/// Scales [source] down until its shorter side is [maxDimension], preserving
/// aspect ratio.
///
/// Deliberately the same rule as the native compressor's `minWidth`/
/// `minHeight` pair, so a photo lands the same size in the bucket whether it
/// came from a phone or a browser.
///
/// Never enlarges. A small image is already cheap to send, and upscaling would
/// spend bandwidth inventing pixels.
img.Image _fit(img.Image source, int maxDimension) {
  final shorterSide =
      source.width < source.height ? source.width : source.height;

  if (shorterSide <= maxDimension) return source;

  final scale = maxDimension / shorterSide;

  return img.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: img.Interpolation.average,
  );
}
