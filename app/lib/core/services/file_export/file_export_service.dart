/// Writing files out of the app - backups and report exports.
///
/// The implementation is chosen at compile time: `_io` writes to the device
/// filesystem, `_web` hands bytes to the browser. Import this file, never the
/// variants.
///
/// The two are interchangeable for writing, and deliberately not for reading:
/// on web a saved file has no path, so `SavedFile.path` is null and the
/// read-back methods throw. Ask `hasAddressableFiles` before offering the user
/// anything that implies a location - a folder picker, a "share this file", a
/// path in a toast.
library;

export 'file_export_service_stub.dart'
    if (dart.library.js_interop) 'file_export_service_web.dart'
    if (dart.library.io) 'file_export_service_io.dart';

export 'file_export_types.dart';
