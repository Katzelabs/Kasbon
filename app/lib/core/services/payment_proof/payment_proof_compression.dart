/// Compression numbers for a payment proof, which are not the product numbers.
///
/// A product photo is decoration: it has to look like the right item in a grid
/// tile, and nobody reads it. A payment proof is a *document* - a photograph of
/// somebody else's phone showing an amount, a timestamp and a merchant name -
/// and the only reason it exists is so a human can read those digits back
/// weeks later during an argument about whether a customer paid.
///
/// That flips what compression is allowed to destroy. Losing detail in a bag of
/// rice costs nothing; losing the difference between Rp15.000 and Rp150.000
/// costs the entire feature.
///
/// See [ImageCompression] for the product settings these deliberately diverge
/// from.
class PaymentProofCompression {
  PaymentProofCompression._();

  /// Shorter side, in pixels, after scaling.
  ///
  /// Same "shorter side" rule as the product compressor - both the native and
  /// pure-Dart paths implement it that way - so a portrait phone photo comes
  /// back about 1000x1778.
  ///
  /// 1000 rather than the product bucket's 800 because the amount typically
  /// occupies well under a fifth of the frame: the cashier photographs a whole
  /// phone held at arm's length, not a crop of the total. At 1000 the digits
  /// land around 100px tall, which survives a re-photograph of a dim screen.
  static const int maxDimension = 1000;

  /// JPEG quality, 1-100.
  ///
  /// 85, above the product bucket's 75, because JPEG spends its error budget on
  /// exactly the wrong thing here. Ringing around high-contrast edges is
  /// invisible on a photo of a snack packet and lands directly on thin white
  /// digits against a dark banking app. The extra bytes buy legibility of the
  /// one thing being stored.
  static const int quality = 85;

  // `mimeType` and `fileExtension` used to be constants here. They are now
  // carried by `CompressedImage`, because a proof shot on a phone is WebP and
  // one uploaded from a browser is still JPEG - see `image_compressor_dart`.

  // Storage arithmetic, kept here because these numbers decide a policy
  // question, and because the earlier version of this comment got it wrong in a
  // way worth not repeating.
  //
  // A proof is ~150 KB as WebP (measured: a 1000px screenshot of a phone is
  // 74 KB, and a real proof is a hand-held photograph *of* a screen, so noisier
  // and larger). It was ~300 KB before the format changed.
  //
  // Retention bounds the total, but the bound is not small:
  //
  //   50 QRIS sales/day x 90 days x 150 KB = ~675 MB
  //   10 QRIS sales/day x 90 days x 150 KB = ~135 MB
  //
  // Against a 1 GB free tier that is one busy shop, or about seven moderate
  // ones. The first draft of this arithmetic claimed a busy shop settled at
  // ~40 MB; that figure implied about 1.5 proofs a day and was simply wrong.
  //
  // So the levers, in the order they actually bite:
  //
  //   1. `shop_settings.payment_proof_retention_days`. A busy shop belongs
  //      nearer 30 days than 90, and 30 puts it back around 225 MB. This is the
  //      dial, and it is per shop precisely because the right value is not the
  //      same for a warung and a furniture seller.
  //   2. Format. WebP already halved it and needed no quality sacrifice.
  //   3. Not quality. Dropping to the product settings buys a little and costs
  //      the legibility the whole feature exists for.
  //
  // Product images, by contrast, have stopped mattering: a photo at 800px WebP
  // is ~15 KB, so a hundred of them is 1.5 MB. Storage is proofs now.
}
