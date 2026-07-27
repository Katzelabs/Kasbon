import 'package:flutter/material.dart';

/// Web has no filesystem the app can read, so a device path renders as the
/// caller's placeholder.
///
/// This is the correct outcome, not a degraded one. The path points at a file
/// on somebody's phone; there is no version of the browser build that could
/// display it. Showing the placeholder is honest, and once RESP_02 moves
/// product images to Supabase Storage these rows carry https URLs that render
/// everywhere - this widget stops being reached for new data.
class AdaptiveLocalImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final WidgetBuilder fallback;

  const AdaptiveLocalImage({
    super.key,
    required this.path,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) => fallback(context);
}
