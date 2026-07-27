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

  return img.encodeJpg(_fit(decoded, maxDimension), quality: quality);
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
