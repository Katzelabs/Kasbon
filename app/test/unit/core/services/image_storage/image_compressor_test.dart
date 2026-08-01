import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kasbon_pos/core/errors/exceptions.dart';
import 'package:kasbon_pos/core/services/image_storage/image_compression_settings.dart';
import 'package:kasbon_pos/core/services/image_storage/image_compressor_dart.dart';

/// Covers the pure-Dart compressor, which is what the browser build uses.
///
/// The native compressor is a plugin and cannot run in a VM test; what is
/// worth pinning here is the resize rule, which was written to match that
/// plugin's `minWidth`/`minHeight` behaviour so a photo lands the same size in
/// the bucket whichever platform uploaded it.
Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);

  // Flat colour compresses to almost nothing and can hide an encoder failure,
  // so give it a gradient with real detail.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }

  return img.encodeJpg(image, quality: 100);
}

/// A JPEG carrying the Exif a phone camera attaches.
///
/// `orientation` is the tag that decides which way up the pixels are meant to
/// be read; the GPS and Make tags stand in for everything else a camera writes,
/// and are what must not survive into a public bucket.
Uint8List _jpegWithExif(int width, int height, {int? orientation}) {
  final image = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }

  if (orientation != null) {
    image.exif.imageIfd.orientation = orientation;
  }
  image.exif.imageIfd['Make'] = 'TestCam';
  image.exif.gpsIfd['GPSLatitudeRef'] = 'S';

  return img.encodeJpg(image, quality: 100);
}

img.Image _decode(Uint8List bytes) => img.decodeImage(bytes)!;

void main() {
  group('compressImage', () {
    test('scales a landscape photo until its shorter side is the maximum',
        () async {
      final compressed = await compressImage(_jpeg(4000, 3000));
      final result = _decode(compressed);

      expect(result.height, 800);
      expect(result.width, 1067); // 4000 * (800 / 3000), rounded
    });

    test('scales a portrait photo on its width', () async {
      final compressed = await compressImage(_jpeg(3000, 4000));
      final result = _decode(compressed);

      expect(result.width, 800);
      expect(result.height, 1067);
    });

    test('leaves an image whose shorter side is already under the maximum',
        () async {
      // A panorama: 2000 wide, but only 400 tall. Scaling this to fit 800 on
      // the short side would enlarge it.
      final compressed = await compressImage(_jpeg(2000, 400));
      final result = _decode(compressed);

      expect(result.width, 2000);
      expect(result.height, 400);
    });

    test('never enlarges a small image', () async {
      final compressed = await compressImage(_jpeg(120, 120));
      final result = _decode(compressed);

      expect(result.width, 120);
      expect(result.height, 120);
    });

    test('honours an explicit maximum', () async {
      final compressed = await compressImage(_jpeg(1000, 1000),
          maxDimension: 200, quality: 60);

      expect(_decode(compressed).width, 200);
    });

    test('produces a JPEG regardless of the source format', () async {
      final png = img.encodePng(img.Image(width: 100, height: 100));

      final compressed = await compressImage(png);

      // SOI marker: the two bytes every JPEG starts with.
      expect(compressed.sublist(0, 2), [0xFF, 0xD8]);
    });

    test('makes a large photo dramatically smaller', () async {
      final original = _jpeg(4000, 3000);

      final compressed = await compressImage(original);

      expect(compressed.length, lessThan(original.length ~/ 4));
    });

    test('strips the camera Exif block, including GPS', () async {
      final compressed = await compressImage(_jpegWithExif(1000, 1000));

      // Not just "no GPS": the whole block goes, matching the native
      // compressor's `keepExif: false`. The embedded camera thumbnail inside it
      // is the part that costs 10-30 KB of a 1 GB quota.
      expect(_decode(compressed).exif.isEmpty, isTrue);
    });

    test('bakes orientation into an image too small to be resized', () async {
      // The regression this guards: `copyResize` bakes orientation, but `_fit`
      // returns the source untouched when the shorter side is already under the
      // maximum. Dropping Exif on that path - with no resize to bake it - left
      // a portrait photo lying on its side.
      final compressed = await compressImage(
        _jpegWithExif(120, 200, orientation: 6),
      );
      final result = _decode(compressed);

      expect(result.width, 200);
      expect(result.height, 120);
    });

    test('bakes orientation when it also resizes', () async {
      final compressed = await compressImage(
        _jpegWithExif(3000, 4000, orientation: 6),
      );
      final result = _decode(compressed);

      // Rotated to 4000x3000 first, then scaled on the shorter side.
      expect(result.height, 800);
      expect(result.width, 1067);
    });

    test('subsamples chroma the way the platform encoders do', () async {
      final source = _jpeg(1000, 1000);

      final compressed = await compressImage(source);
      final fullChroma = img.encodeJpg(
        img.copyResize(
          _decode(source),
          width: ImageCompression.maxDimension,
          height: ImageCompression.maxDimension,
          interpolation: img.Interpolation.average,
        ),
        quality: ImageCompression.quality,
        chroma: img.JpegChroma.yuv444,
      );

      expect(compressed.length, lessThan(fullChroma.length));
    });

    test('throws a readable failure when the bytes are not an image', () {
      expect(
        () => compressImage(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(
          isA<ImageStorageException>()
              .having((e) => e.code, 'code', 'DECODE_FAILED'),
        ),
      );
    });

    test('throws a readable failure when the file is truncated', () {
      // A real JPEG header followed by nothing. Decoders recognise the format
      // and then run off the end of the buffer - which used to surface to the
      // shop owner as "RangeError: Value not in range".
      final truncated = Uint8List.fromList(
        _jpeg(200, 200).sublist(0, 40),
      );

      expect(
        () => compressImage(truncated),
        throwsA(
          isA<ImageStorageException>()
              .having((e) => e.code, 'code', 'DECODE_FAILED'),
        ),
      );
    });
  });
}
