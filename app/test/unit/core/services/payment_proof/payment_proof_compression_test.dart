@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kasbon_pos/core/services/image_storage/image_compression_settings.dart';
import 'package:kasbon_pos/core/services/image_storage/image_compressor_dart.dart';
import 'package:kasbon_pos/core/services/payment_proof/payment_proof_compression.dart';

/// Does a compressed payment proof still show the amount?
///
/// The proof settings exist for one reason - somebody has to read digits off
/// the photo weeks later - so "it compressed without throwing" is not the test.
/// These check the two properties that decide legibility: how far the image is
/// scaled, and how much JPEG is allowed to smear the high-contrast edges that
/// digits are made of.
///
/// Exercises the pure-Dart compressor directly rather than the `compressImage`
/// facade. The facade resolves to `flutter_image_compress` on the VM, which
/// needs a platform plugin that `flutter test` does not have. The Dart path is
/// the one the web build uses and it implements the same "shorter side" rule,
/// so the arithmetic under test is the shared arithmetic.
///
/// Set KASBON_PROOF_SAMPLES to a directory to dump the JPEGs and look at them:
///
///   KASBON_PROOF_SAMPLES=/tmp/proofs flutter test \
///     test/unit/core/services/payment_proof/payment_proof_compression_test.dart
void main() {
  /// A stand-in for what a cashier actually photographs: a phone held at arm's
  /// length showing a wallet's success screen.
  ///
  /// Portrait 1080x1920 with a dark background and light text, because that is
  /// the hard case for JPEG - the ringing it trades away first lands exactly on
  /// thin light glyphs against dark, which is what the amount is.
  ///
  /// The amount is drawn at a size proportional to the frame the same way it
  /// sits on a real screen: large, but nowhere near the full width.
  img.Image syntheticSuccessScreen() {
    final image = img.Image(width: 1080, height: 1920);
    img.fill(image, color: img.ColorRgb8(18, 20, 28));

    // Chrome around the amount, so the compressor is not handed an
    // unrealistically empty frame that compresses better than a real photo.
    img.fillRect(image,
        x1: 0, y1: 0, x2: 1080, y2: 220, color: img.ColorRgb8(0, 122, 94));
    img.drawString(image, 'Pembayaran Berhasil',
        font: img.arial48, x: 90, y: 90, color: img.ColorRgb8(255, 255, 255));

    // The digits everything else is in service of.
    img.drawString(image, 'Rp150.000',
        font: img.arial48, x: 90, y: 780, color: img.ColorRgb8(255, 255, 255));

    // Fine print - the first thing to become unreadable, and the reason not to
    // judge legibility on the headline amount alone.
    img.drawString(image, 'REF 0198237741  31 Jul 2026 14:22',
        font: img.arial14, x: 90, y: 900, color: img.ColorRgb8(176, 180, 190));
    img.drawString(image, 'TOKO BAROKAH - QRIS GPN',
        font: img.arial14, x: 90, y: 930, color: img.ColorRgb8(176, 180, 190));

    return image;
  }

  late Uint8List original;

  setUpAll(() {
    original = img.encodeJpg(syntheticSuccessScreen(), quality: 100);
  });

  /// Writes [bytes] where a human can open it, when the env var is set.
  void maybeDump(String name, Uint8List bytes) {
    final dir = Platform.environment['KASBON_PROOF_SAMPLES'];
    if (dir == null) return;
    Directory(dir).createSync(recursive: true);
    File('$dir/$name').writeAsBytesSync(bytes);
  }

  test('scales the shorter side to the proof dimension, not the product one',
      () async {
    final compressed = await compressImage(
      original,
      maxDimension: PaymentProofCompression.maxDimension,
      quality: PaymentProofCompression.quality,
    );
    maybeDump('proof_1000_q85.jpg', compressed.bytes);

    final decoded = img.decodeImage(compressed.bytes)!;

    // 1080x1920 portrait: the shorter side is the width.
    expect(decoded.width, PaymentProofCompression.maxDimension);
    expect(decoded.height, 1778); // 1920 * (1000/1080), rounded

    // The point of diverging from the product settings at all.
    expect(
      PaymentProofCompression.maxDimension,
      greaterThan(ImageCompression.maxDimension),
      reason: 'a proof is read, not glanced at',
    );
    expect(
      PaymentProofCompression.quality,
      greaterThan(ImageCompression.quality),
      reason: 'JPEG ringing lands on exactly the glyphs being stored',
    );
  });

  test('keeps more of the image than the product settings would', () async {
    final asProof = await compressImage(
      original,
      maxDimension: PaymentProofCompression.maxDimension,
      quality: PaymentProofCompression.quality,
    );
    final asProduct = await compressImage(
      original,
      maxDimension: ImageCompression.maxDimension,
      quality: ImageCompression.quality,
    );
    maybeDump('product_800_q75.jpg', asProduct.bytes);

    expect(asProof.bytes.length, greaterThan(asProduct.bytes.length));
  });

  // The number the storage arithmetic in PaymentProofCompression is built on.
  // If a settings change quietly triples the file size, the retention problem
  // documented there arrives three times sooner, so it should fail here first.
  test('a proof stays within the size the storage budget assumes', () async {
    final compressed = await compressImage(
      original,
      maxDimension: PaymentProofCompression.maxDimension,
      quality: PaymentProofCompression.quality,
    );

    expect(
      compressed.bytes.length,
      lessThan(600 * 1024),
      reason: 'budget assumes ~300 KB for a photographic proof; this synthetic '
          'screen is flatter than a real photo so it should come in well under',
    );
  });
}
