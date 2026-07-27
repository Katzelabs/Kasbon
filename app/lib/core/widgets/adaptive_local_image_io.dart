import 'dart:io';

import 'package:flutter/material.dart';

/// Renders the image at a device filesystem path.
///
/// [path] may carry a `file://` prefix; it is stripped, matching what the
/// three call sites did individually before this widget existed.
///
/// [fallback] is shown when the file is missing or unreadable - a stale path
/// after a reinstall is normal, not exceptional.
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
  Widget build(BuildContext context) {
    return Image.file(
      File(path.replaceFirst('file://', '')),
      fit: fit,
      errorBuilder: (context, _, __) => fallback(context),
    );
  }
}
