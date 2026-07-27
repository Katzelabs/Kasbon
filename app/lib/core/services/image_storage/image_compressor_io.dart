import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../errors/exceptions.dart';
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
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int maxDimension = ImageCompression.maxDimension,
  int quality = ImageCompression.quality,
}) async {
  final compressed = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth: maxDimension,
    minHeight: maxDimension,
    quality: quality,
    format: CompressFormat.jpeg,
  );

  if (compressed.isEmpty) {
    throw const ImageStorageException(
      message: 'Gagal mengompres gambar',
      code: 'COMPRESSION_FAILED',
    );
  }

  return compressed;
}
