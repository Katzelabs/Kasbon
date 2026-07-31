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

  /// Content type every stored proof carries.
  static const String mimeType = 'image/jpeg';

  /// Extension matching [mimeType].
  static const String fileExtension = 'jpg';

  // Storage arithmetic, recorded here because these numbers decide a policy
  // question that compression cannot solve:
  //
  //   ~300 KB per proof at the settings above
  //   x 50 QRIS sales/day for a busy warung
  //   = ~15 MB/day, ~5.5 GB/year
  //
  // Supabase's free tier is 1 GB, so a shop that photographs every QRIS sale
  // fills it in roughly ten weeks. Dropping to the product settings (800/q75,
  // ~180 KB) only stretches that to about four months while making the digits
  // harder to read - it trades the feature's purpose for a delay, not a fix.
  //
  // The lever is retention, not quality: a proof stops being useful once a sale
  // is too old to dispute. Nothing in this app deletes them yet, which is a gap
  // to close before a real shop runs on it for a year - not a reason to store
  // unreadable photographs in the meantime.
}
