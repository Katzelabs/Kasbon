import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:kasbon_pos/core/services/image_storage/compressed_image.dart';
import 'package:kasbon_pos/core/services/image_storage/image_compressor.dart';

/// The native compressor, running against a real platform codec.
///
/// Everything else about compression is covered by ordinary VM tests, but those
/// exercise the pure-Dart path - which is the browser's, not a phone's. The
/// native path is a plugin, so a `flutter test` run never touches it, and the
/// claim that a phone now uploads WebP went unverified through an entire
/// release of work.
///
/// Run it against whichever platform you care about:
///
///   flutter test integration_test/native_compressor_test.dart -d macos
///   flutter test integration_test/native_compressor_test.dart -d <device-id>
///
/// **A pass on macOS does not prove Android or iOS.** The three use different
/// encoders, and macOS in particular does *not* support WebP at all - see
/// below. What every platform must agree on is the invariant these tests are
/// really about: whatever comes back, the format it is labelled with is the
/// format it actually is.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A photograph-ish source: smooth structure, which is what a real photo is
  /// and what WebP is good at. Flat colour would compress to nothing on both
  /// formats and prove neither.
  Uint8List source(int width, int height) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, (x * 255) ~/ width, (y * 255) ~/ height,
            ((x + y) * 255) ~/ (width + height));
      }
    }
    return img.encodeJpg(image, quality: 100);
  }

  test('what it says it produced is what it produced', () async {
    final compressed = await compressImage(source(1200, 900));

    final magic = switch (compressed.format) {
      ImageFormat.jpeg => [0xFF, 0xD8, 0xFF],
      ImageFormat.webp => [0x52, 0x49, 0x46, 0x46], // RIFF
    };

    expect(
      compressed.bytes.sublist(0, magic.length),
      magic,
      reason: 'declared ${compressed.format.mimeType}, which decides both the '
          'object extension and the Content-Type it is stored under',
    );

    // The specific way this went wrong: `flutter_image_compress_macos` maps a
    // WebP request onto its `default:` branch (kUTTypeJPEG), succeeds, and
    // returns a JPEG. Trusting the request rather than the bytes stored JPEGs
    // labelled `image/webp`.
    // ignore: avoid_print
    print('platform produced: ${compressed.format.mimeType} '
        '(${compressed.bytes.length} bytes)');
  });

  test('resizes on the shorter side, matching the pure-Dart path', () async {
    final compressed = await compressImage(source(4000, 3000));
    final decoded = img.decodeImage(compressed.bytes)!;

    // `minWidth`/`minHeight` mean "scale until the shorter side reaches this".
    // The Dart compressor was written to match, so a photo lands the same size
    // whichever platform uploaded it.
    expect(decoded.height, 800);
    expect(decoded.width, closeTo(1067, 2));
  });

  test('a small image is not enlarged', () async {
    final compressed = await compressImage(source(120, 120));
    final decoded = img.decodeImage(compressed.bytes)!;

    expect(decoded.width, 120);
    expect(decoded.height, 120);
  });

  test('unreadable bytes fail rather than upload the original', () async {
    await expectLater(
      compressImage(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(anything),
    );
  });
}
