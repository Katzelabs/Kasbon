/// Shrinking a picked photo before it is uploaded.
///
/// Split by platform because the fast path is a native plugin:
/// `flutter_image_compress` hands the work to Android/iOS/macOS system codecs,
/// while the browser has no such plugin and falls back to a pure-Dart decode.
///
/// **Not an optimisation - a requirement.** `image_picker_for_web` silently
/// ignores `maxWidth`, `maxHeight` and `imageQuality`, so on web the picker
/// returns the camera's original file. Without this step a shop owner on
/// Indonesian mobile data would upload a 4 MB photo to attach to a product.
library;

export 'image_compressor_stub.dart'
    if (dart.library.js_interop) 'image_compressor_web.dart'
    if (dart.library.io) 'image_compressor_io.dart';
