import 'package:flutter/material.dart';

/// Fallback for platforms with neither `dart:io` nor JS interop.
///
/// Unreachable in practice; exists to give the conditional export a default.
/// Renders the placeholder, which is the safe answer for a platform we cannot
/// read files on.
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
