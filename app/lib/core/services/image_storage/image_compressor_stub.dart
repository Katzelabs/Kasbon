import 'dart:typed_data';

import 'image_compression_settings.dart';

/// Fallback for platforms with neither `dart:io` nor JS interop.
///
/// Unreachable in practice; exists to give the conditional export a default.
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int maxDimension = ImageCompression.maxDimension,
  int quality = ImageCompression.quality,
}) async =>
    throw UnsupportedError('No image compressor for this platform');
