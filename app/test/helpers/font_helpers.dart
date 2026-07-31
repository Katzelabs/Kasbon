import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's real typeface so text in a widget test measures roughly the
/// way it does on a device.
///
/// Without this, `flutter test` draws every glyph as a square the size of the
/// font - the standard test font has no proportional metrics at all. A 9-letter
/// word at 14pt measures 126 logical pixels instead of about 70, so any layout
/// with less than ~80% slack "overflows" in tests while being perfectly fine on
/// a phone. Two dialogs in this app looked broken for exactly that reason and
/// were not.
///
/// That matters beyond noise: an overflow throws, so a purely behavioural test
/// fails on a rendering artifact it never meant to exercise. Worse, once you
/// learn to expect the artifact, a *real* overflow stops being distinguishable
/// from it.
///
/// Call from `setUpAll` in any test that renders text inside a constrained box
/// and asserts on behaviour:
///
/// ```dart
/// setUpAll(loadAppFonts);
/// ```
///
/// Caveat worth knowing: [FontLoader] registers every face under one family
/// name and does not model weights, so bold text is measured with whichever
/// face resolves first. Real bold PlusJakartaSans is a little wider than what a
/// test sees, which is close enough to catch a layout with no slack but not
/// exact enough to assert pixel positions. Pixel-exact checks belong in the
/// golden tests under `test/widget/shared/modern/layout/`.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader('PlusJakartaSans');
  for (final asset in const [
    'assets/fonts/PlusJakartaSans-Regular.ttf',
    'assets/fonts/PlusJakartaSans-Medium.ttf',
    'assets/fonts/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(asset));
  }

  await loader.load();
}
