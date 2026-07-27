import 'package:flutter/foundation.dart';

/// Platform capability checks, expressed as questions about *what the app can
/// do* rather than *which operating system it is on*.
///
/// This file deliberately imports only `package:flutter/foundation.dart`. It
/// must never import `dart:io`, because it is imported from widgets, services
/// and `main()` alike - a single `dart:io` here would break the web build
/// everywhere at once, which is precisely the situation this class exists to
/// prevent.
///
/// Prefer a named capability over a raw platform check at the call site.
/// `AppPlatform.supportsHaptics` says why the branch exists; `Platform.isIOS ||
/// Platform.isAndroid` makes the next reader work it out, and gets copied
/// wrongly.
class AppPlatform {
  AppPlatform._();

  /// Running in a browser (including mobile browsers).
  static bool get isWeb => kIsWeb;

  /// Running natively on a phone or tablet OS.
  ///
  /// False in a mobile browser: the OS is Android, but the app is subject to
  /// browser rules, which is what actually matters for every caller.
  static bool get isMobileOs =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Running natively on a desktop OS.
  static bool get isDesktopOs =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Whether the device has a haptic engine worth calling.
  ///
  /// `HapticFeedback` is a no-op on web and desktop rather than a crash, so
  /// this is about not pretending - a button that claims to buzz and doesn't
  /// is a lie in the code, not a bug in the build.
  static bool get supportsHaptics => isMobileOs;

  /// Whether `SystemChrome` overlay and orientation calls mean anything.
  ///
  /// On web the browser owns the status bar, the address bar and rotation;
  /// calling `setSystemUIOverlayStyle` there is wasted work on every build.
  static bool get usesSystemOverlayStyle => isMobileOs;

  /// Whether the platform has a runtime permission prompt to request.
  ///
  /// Browsers grant camera and file access through their own UI in response to
  /// a user gesture, so `permission_handler` has nothing to ask for.
  static bool get needsRuntimePermissions => isMobileOs;

  /// Whether the primary input is a mouse or trackpad rather than a finger.
  ///
  /// Drives hover affordances, pointer cursors and keyboard shortcuts. Web is
  /// included because a desktop browser is the main target - a touchscreen
  /// laptop is a deliberate false positive, since hover states that do nothing
  /// are harmless while missing ones are not.
  static bool get isPointerFirst => isWeb || isDesktopOs;

  /// Whether the app can write to a user-visible filesystem path.
  ///
  /// False on web, where an "export" is a browser download and there is no
  /// path to show the user afterwards.
  static bool get hasFileSystem => !isWeb;
}
