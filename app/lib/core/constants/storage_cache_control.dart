/// How long a stored image may be cached, in seconds.
///
/// Supabase Storage defaults to `3600` - one hour - which is roughly the worst
/// possible value here. A shop owner opening the till five times a day
/// re-downloads the entire product grid on almost every launch, and a hundred
/// product photos is ~15 MB of egress each time. That single default is most of
/// the app's traffic against a 5 GB monthly quota.
///
/// A year is safe because neither bucket ever overwrites an object. Both lay
/// their paths out as `<user_id>/<owner_id>/<timestamp>.<ext>`, so replacing a
/// photo writes a *new* object and the old URL simply stops being referenced -
/// the property `SupabaseImageStorageService` already documents as the reason a
/// stale image cannot be served from a CDN. Nothing a long lifetime could make
/// stale exists.
///
/// This is not the same lever as the client-side image cache. This header is
/// what lets the CDN answer for the object at all, which is also what moves the
/// bytes onto the cheaper cached-egress line; the client cache is what stops the
/// request leaving the device. Both are wanted, and neither substitutes for the
/// other - a fresh install, a cleared cache or a second device all land here.
class StorageCacheControl {
  const StorageCacheControl._();

  /// One year, the maximum `Cache-Control: max-age` worth asking for.
  static const String maxAge = '31536000';
}
