/// Rendering an image that lives at a device filesystem path.
///
/// Three widgets need this, and all three used to reach for `dart:io` directly
/// to build an `Image.file`. That single import is what kept the product
/// feature off web.
///
/// These paths are legacy data, and no new ones are created: product images
/// now go to Supabase Storage and come back as https URLs. What remains is
/// rows written by the old local storage, which put an absolute device path in
/// `products.image_url`. Those were never valid on another device and are
/// never valid in a browser - the web implementation therefore renders the
/// caller's placeholder rather than pretending.
library;

export 'adaptive_local_image_stub.dart'
    if (dart.library.js_interop) 'adaptive_local_image_web.dart'
    if (dart.library.io) 'adaptive_local_image_io.dart';
