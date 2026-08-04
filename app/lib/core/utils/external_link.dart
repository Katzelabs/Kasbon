import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/modern/modern.dart';

/// Opening something that is not part of this app.
///
/// This lived as a private helper inside `about_screen.dart` until the settings
/// hub needed the same behaviour for its privacy-policy row. The rules below
/// are the reason it is worth sharing rather than copying: they are not obvious
/// and both callers get them wrong the same way.
class ExternalLink {
  ExternalLink._();

  /// Launches [url], reporting failure as a toast rather than an exception.
  ///
  /// `canLaunchUrl` is deliberately not consulted as a veto: on the web it
  /// answers for a scheme rather than for a handler, and on Android it needs a
  /// `<queries>` entry to answer honestly at all - so a false there is a
  /// "probably not", and the attempt is still worth making. The error only
  /// surfaces once the launch itself has actually failed.
  ///
  /// [mode] defaults to an external application because every current caller is
  /// a web page that belongs in the browser. `mailto:` has no external-
  /// application equivalent to fall back on and must pass
  /// [LaunchMode.platformDefault].
  static Future<void> open(
    BuildContext context,
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
    required String failureMessage,
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(url, mode: mode);
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      ModernToast.error(context, failureMessage);
    }
  }

  /// [open] for a URL that is a string constant, e.g. one from `SupportContacts`.
  static Future<void> openUrl(
    BuildContext context,
    String url, {
    String failureMessage = 'Tidak dapat membuka link',
  }) {
    return open(context, Uri.parse(url), failureMessage: failureMessage);
  }
}
