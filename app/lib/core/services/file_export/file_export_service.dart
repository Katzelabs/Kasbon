/// Writing files out of the app - backups and report exports.
///
/// The implementation is chosen at compile time: `_io` writes to the device
/// filesystem, `_web` hands bytes to the browser. Import this file, never the
/// variants.
///
/// The web variant is a stub until RESP_02, which implements the Blob download
/// and makes backup and report export work in the browser. It throws a clear
/// error rather than silently doing nothing, so an unfinished path cannot look
/// like a successful export.
library;

export 'file_export_service_stub.dart'
    if (dart.library.js_interop) 'file_export_service_web.dart'
    if (dart.library.io) 'file_export_service_io.dart';

export 'file_export_types.dart';
