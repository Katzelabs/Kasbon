/// Chooses the [ImageStorageService] implementation for the current platform.
///
/// Exists because the local implementation imports `dart:io`, and `injection.dart`
/// is reachable from `main()` and most widgets - naming the concrete class there
/// would drag `dart:io` into the web build transitively, which is exactly the
/// failure mode the rest of RESP_01 removes.
///
/// Short-lived. RESP_02 moves product images to Supabase Storage on every
/// platform, at which point both variants collapse into one implementation and
/// this indirection goes away.
library;

export 'image_storage_factory_stub.dart'
    if (dart.library.js_interop) 'image_storage_factory_web.dart'
    if (dart.library.io) 'image_storage_factory_io.dart';
