import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

/// Helpers for the hex colour strings stored in `categories.color`.
class ColorUtils {
  ColorUtils._();

  /// Parse a hex colour string into a [Color].
  ///
  /// Accepts `#RRGGBB`, `RRGGBB`, `#AARRGGBB` and `AARRGGBB`. Anything that
  /// does not parse falls back to [fallback] rather than throwing - a bad
  /// colour in the database should not take down a whole chart.
  static Color fromHex(String? hex, {Color fallback = AppColors.textTertiary}) {
    if (hex == null) return fallback;

    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) {
      // No alpha channel supplied - default to fully opaque.
      value = 'FF$value';
    }
    if (value.length != 8) return fallback;

    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  /// Pick a stable palette colour for [index], cycling through
  /// [AppColors.categoryColors].
  ///
  /// Used when a chart series has no colour of its own, so the same slice keeps
  /// the same colour between rebuilds.
  static Color paletteAt(int index) {
    const palette = AppColors.categoryColors;
    return palette[index % palette.length];
  }

  /// A readable foreground colour for text drawn on [background].
  ///
  /// Uses the standard relative-luminance threshold so labels stay legible on
  /// both a pale amber slice and a deep blue one.
  static Color onColor(Color background) {
    return background.computeLuminance() > 0.5
        ? AppColors.textPrimary
        : Colors.white;
  }
}
