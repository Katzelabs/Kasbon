/// Strips customer, money and credential data out of anything on its way to a
/// crash reporter.
///
/// A KASBON crash report would otherwise carry a shop's books off the device.
/// A debt row names a real person and what they still owe. A payment-proof path
/// points at a photo of someone's banking app. A Supabase REST call puts the
/// search filter in the query string, so `?customer_name=ilike.*sri*` is a
/// breadcrumb by default. None of that is needed to fix a crash, and all of it
/// is someone else's.
///
/// The scrub keys on **field names**, not on value shapes. Guessing at shapes
/// is how a redactor either eats stack frames (`Rp` looks like money, so does a
/// line number) or misses the one field that mattered. A name is unambiguous.
///
/// It runs over the three places a value reaches an event:
///
/// 1. **Structured maps** — breadcrumb `data`, contexts, extra.
/// 2. **URLs** — query strings go entirely; storage object paths lose
///    everything after the bucket.
/// 3. **Free text** — an exception message that quoted the row it choked on.
///
/// Stack frames are deliberately left alone. They are code, not data, and they
/// are the entire reason the report is being sent.
///
/// Pure Dart with no Sentry import, so the rules can be tested directly. The
/// Sentry wiring that calls this lives in `crash_reporting.dart`.
class PiiScrubber {
  const PiiScrubber._();

  /// What a redacted value is replaced with. Deliberately visible: a reader
  /// should be able to tell "this field was removed" from "this field was
  /// absent", because those two suggest very different bugs.
  static const String redacted = '[redacted]';

  /// Buckets whose object paths are per-tenant and name a photo.
  ///
  /// Kept in sync with `20260804010006_storage_buckets.sql`. A bucket missing
  /// here degrades to "path not redacted", not to a crash.
  static const Set<String> storageBuckets = {
    'product-images',
    'payment-proofs',
  };

  /// Field names whose values never leave the device.
  ///
  /// Written in `snake_case` — matching is case-insensitive and tolerates the
  /// `camelCase` spelling of the same field, so one entry covers
  /// `customer_name`, `customerName` and `CustomerName`. Err toward adding:
  /// a redacted field costs a round trip to reproduce, an leaked one cannot be
  /// taken back.
  static const Set<String> sensitiveKeys = {
    // Who the customer is. The whole point of hutang tracking is that these
    // are real named neighbours.
    'customer_name',
    'customer_phone',
    'customer_address',
    'phone',
    'email',
    'address',
    'notes',

    // What they owe, and what the shop makes. Profit margins are the reason
    // KASBON exists and are nobody else's business.
    'amount',
    'total_amount',
    'paid_amount',
    'remaining_amount',
    'change_amount',
    'subtotal',
    'discount',
    'total',
    'price',
    'cost_price',
    'selling_price',
    'unit_price',
    'profit',
    'balance',

    // Where the photos are. A payment proof is a screenshot of a bank app.
    'payment_proof_path',
    'image_url',
    'avatar_url',

    // Who the shop is.
    'shop_name',
    'shop_address',
    'shop_phone',
    'owner_name',
    'full_name',

    // Credentials. Should never be in an event at all; belt and braces.
    'password',
    'token',
    'access_token',
    'refresh_token',
    'apikey',
    'api_key',
    'authorization',
    'secret',
  };

  static final RegExp _nonAlphanumeric = RegExp('[^a-z0-9]');

  /// `customer_name`, `customerName` and `Customer Name` are one key.
  static String _normalise(String key) =>
      key.toLowerCase().replaceAll(_nonAlphanumeric, '');

  static final Set<String> _normalisedKeys =
      sensitiveKeys.map(_normalise).toSet();

  static bool isSensitiveKey(String key) =>
      _normalisedKeys.contains(_normalise(key));

  /// `customer_name` → `customer_?name`, which under `caseSensitive: false`
  /// also matches `customerName`. Built from the same set as [isSensitiveKey]
  /// so the two can never drift.
  static final String _keyPattern =
      sensitiveKeys.map((key) => key.split('_').join('_?')).join('|');

  /// A Postgres constraint violation quotes the offending row:
  /// `Key (customer_name)=(Sri Wahyuni) already exists.`
  static final RegExp _parenthesisedPair = RegExp(
    r'\((' + _keyPattern + r')\)\s*=\s*\([^)]*\)',
    caseSensitive: false,
  );

  /// `"customer_name":"Sri"` and `"total_amount": 50000`.
  static final RegExp _jsonPair = RegExp(
    '"($_keyPattern)"\\s*:\\s*("(?:[^"\\\\]|\\\\.)*"|[^,}\\s]+)',
    caseSensitive: false,
  );

  /// `customer_name=ilike.*sri*` and `total_amount: 50000`.
  static final RegExp _plainPair = RegExp(
    '($_keyPattern)\\s*[=:]\\s*[^,&\\s)\\]}]+',
    caseSensitive: false,
  );

  static final RegExp _urlInText = RegExp(
    r'https?://[^\s"' "'" r'<>\]}]+',
    caseSensitive: false,
  );

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Redacts a URL, keeping only what identifies *which call* failed.
  ///
  /// The query string goes wholesale — PostgREST puts every filter there, so
  /// there is no subset worth keeping and a denylist would miss the next one.
  /// The path stays, because `/rest/v1/transactions` is the useful half and
  /// carries no values; the exception is a storage object path, where
  /// everything after the bucket names a tenant and a photo.
  static String scrubUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      // Not parseable as an absolute URL. It may still be an object path, so
      // it is not safe to return unchanged.
      return redacted;
    }

    final buffer = StringBuffer()
      ..write(uri.scheme)
      ..write('://')
      ..write(uri.host);
    if (uri.hasPort) {
      buffer.write(':${uri.port}');
    }
    for (final segment in _scrubPathSegments(uri.pathSegments)) {
      buffer
        ..write('/')
        ..write(segment);
    }
    if (uri.hasQuery) {
      buffer.write('?$redacted');
    }
    if (uri.hasFragment) {
      buffer.write('#$redacted');
    }
    return buffer.toString();
  }

  static List<String> _scrubPathSegments(List<String> segments) {
    final scrubbed = <String>[];
    var insideBucket = false;
    for (final segment in segments) {
      if (insideBucket || _uuid.hasMatch(segment)) {
        // A bare UUID is a tenant or a row id wherever it appears, not only
        // under a bucket.
        scrubbed.add(redacted);
        continue;
      }
      scrubbed.add(segment);
      if (storageBuckets.contains(segment)) {
        insideBucket = true;
      }
    }
    return scrubbed;
  }

  /// Redacts sensitive values embedded in free text.
  ///
  /// Order matters: URLs go first so their query strings are handled as URLs
  /// rather than picked apart pair by pair, and the parenthesised form goes
  /// before the plain one so `(customer_name)=(Sri)` is not left as
  /// `(customer_name)=([redacted])` with a dangling paren.
  static String scrubText(String value) {
    var text = value.replaceAllMapped(
      _urlInText,
      (match) => scrubUrl(match.group(0)!),
    );
    text = text.replaceAllMapped(
      _parenthesisedPair,
      (match) => '(${match.group(1)})=($redacted)',
    );
    text = text.replaceAllMapped(
      _jsonPair,
      (match) => '"${match.group(1)}":"$redacted"',
    );
    text = text.replaceAllMapped(
      _plainPair,
      (match) => '${match.group(1)}=$redacted',
    );
    return text;
  }

  /// Redacts a map by key, recursing into nested maps and lists.
  ///
  /// A sensitive key drops its whole subtree: if `customer` is sensitive, its
  /// contents are not inspected field by field, they are gone.
  static Map<String, dynamic> scrubMap(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (isSensitiveKey(key)) {
        return MapEntry(key, redacted);
      }
      return MapEntry(key, scrubValue(value));
    });
  }

  /// Redacts a value of unknown shape.
  ///
  /// Bare numbers and booleans pass through: without a key there is no way to
  /// tell a debt from a list length, and redacting every integer would leave a
  /// report that cannot be read at all.
  static Object? scrubValue(Object? value) {
    if (value is Map) {
      return scrubMap(value.map(
        (key, nested) => MapEntry(key.toString(), nested),
      ));
    }
    if (value is List) {
      return value.map(scrubValue).toList();
    }
    if (value is String) {
      return scrubText(value);
    }
    return value;
  }
}
