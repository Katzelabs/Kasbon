import 'image_storage_service.dart';

/// Fallback for platforms with neither `dart:io` nor JS interop.
///
/// Unreachable in practice; exists to give the conditional export a default.
ImageStorageService createImageStorageService() => throw UnsupportedError(
      'No image storage implementation for this platform',
    );
