import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../shared/modern/modern.dart';

/// A network image that is fetched once per device rather than once per launch.
///
/// ## Why this exists
///
/// `Image.network` caches in Flutter's in-memory `ImageCache` and nowhere else,
/// so every cold start re-downloads every photo on screen. For a shop with a
/// hundred products that is ~15 MB of egress per launch, several launches a
/// day, against a 5 GB monthly quota - which made product photos roughly all of
/// the app's traffic. Nothing about the images changed; they were just fetched
/// over and over.
///
/// Caching them is safe because neither bucket overwrites an object: a replaced
/// photo is written to a new `<user_id>/<owner_id>/<timestamp>.<ext>` path, so
/// a cached entry can never be stale, only unreferenced. The same property is
/// what lets uploads set a one-year `Cache-Control` (see [StorageCacheControl]).
///
/// The two layers are complements, not alternatives: this one stops the request
/// leaving the device, the header lets a CDN answer the ones that do. On web
/// this widget delegates to the browser's own HTTP cache, so there the header
/// *is* the mechanism - which is why both landed together.
///
/// ## [cacheKey] is load-bearing for private buckets
///
/// The cache keys on the URL by default, which is right for `product-images`:
/// a public URL is a pure function of the object path.
///
/// It is wrong for `payment-proofs`. That bucket is private and read through
/// signed URLs, and a fresh signature is minted per view - so the URL never
/// repeats, every entry is a miss, and the cache would grow without ever being
/// read from. Callers there pass the object path as [cacheKey], which is the
/// part that identifies the image rather than the permission to see it.
class CachedRemoteImage extends StatelessWidget {
  /// Cache store, or null for the package default.
  ///
  /// Exists for widget tests, which cannot use the real one: it reaches for
  /// `path_provider` (no plugin under a test binding) and for the network
  /// (`HttpClient` answers 400 and never gets further). The result is not an
  /// error but a hang - the image resolves to nothing, no frame is ever
  /// scheduled, and `pumpAndSettle` times out somewhere far from the cause.
  ///
  /// A test that renders anything with a photo installs an inert manager here;
  /// see `installInertImageCache` in `test/helpers/test_helpers.dart`.
  static BaseCacheManager? cacheManager;

  const CachedRemoteImage({
    super.key,
    required this.url,
    required this.errorWidget,
    this.cacheKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.showProgress = false,
  });

  /// Where to fetch the image from. May carry a short-lived signature.
  final String url;

  /// Rendered when the fetch fails, or the reference points at nothing.
  final Widget errorWidget;

  /// Identity of the image, when that differs from [url]. See the class doc.
  final String? cacheKey;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Whether to show a spinner while loading.
  ///
  /// Off by default: a grid tile has a placeholder box already and a dozen
  /// spinners appearing at once reads as breakage rather than progress. The
  /// single large image on a detail screen is the case that wants one.
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey,
      cacheManager: cacheManager,
      fit: fit,
      width: width,
      height: height,
      placeholder: showProgress
          ? (_, __) => const Center(child: ModernLoading.small())
          : null,
      errorWidget: (_, __, ___) => errorWidget,
    );
  }
}
