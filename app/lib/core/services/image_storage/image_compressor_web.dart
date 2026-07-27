/// Browser compression.
///
/// `flutter_image_compress` does ship a web implementation, but it is a canvas
/// shim that only implements two of the plugin's methods and pulls in the
/// legacy `dart:html` interop. `package:image` is pure Dart, works identically
/// under both the JS and Wasm compilers, and is already needed here for the
/// resize the picker refuses to do on web.
library;

export 'image_compressor_dart.dart';
