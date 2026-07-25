import 'package:flutter/material.dart';

/// Application elevation ramp.
///
/// Every level is built from two layers: a wide, very low-opacity ambient
/// shadow that reads as depth, plus a tight contact shadow that anchors the
/// element to the surface. A single hard shadow (the previous approach - 10%
/// black at 4px blur) is what makes an interface read as dated; real depth
/// comes from spreading far more blur across far less opacity.
///
/// Levels are semantic, not numeric - pick by what the element *is*, so the
/// whole app lifts and settles consistently.
class AppShadows {
  AppShadows._();

  static const Color _ambient = Color(0xFF0F172A);

  static List<BoxShadow> _layer({
    required double blur,
    required double y,
    required double opacity,
    double spread = 0,
  }) =>
      [
        BoxShadow(
          color: _ambient.withValues(alpha: opacity),
          blurRadius: blur,
          offset: Offset(0, y),
          spreadRadius: spread,
        ),
      ];

  /// No elevation. Use for flush, inline surfaces.
  static const List<BoxShadow> none = [];

  /// Barely-there lift for chips, small badges and inline controls.
  static final List<BoxShadow> xs = [
    ..._layer(blur: 2, y: 1, opacity: 0.04),
  ];

  /// Resting state for cards and list rows - the app's default surface.
  static final List<BoxShadow> sm = [
    ..._layer(blur: 3, y: 1, opacity: 0.04),
    ..._layer(blur: 8, y: 2, opacity: 0.03),
  ];

  /// Raised surfaces: hovered/pressed cards, dropdowns, popovers.
  static final List<BoxShadow> md = [
    ..._layer(blur: 6, y: 2, opacity: 0.05),
    ..._layer(blur: 16, y: 4, opacity: 0.04),
  ];

  /// Floating surfaces: bottom sheets, FABs, toasts.
  static final List<BoxShadow> lg = [
    ..._layer(blur: 10, y: 3, opacity: 0.06),
    ..._layer(blur: 28, y: 8, opacity: 0.05),
  ];

  /// Modal surfaces that must clearly detach from everything behind them.
  static final List<BoxShadow> xl = [
    ..._layer(blur: 14, y: 4, opacity: 0.07),
    ..._layer(blur: 44, y: 16, opacity: 0.06),
  ];

  /// Upward shadow for bottom-anchored bars (bottom nav, cart summary,
  /// sticky footers), where the light source logic inverts.
  static final List<BoxShadow> up = [
    BoxShadow(
      color: _ambient.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, -4),
    ),
    BoxShadow(
      color: _ambient.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, -1),
    ),
  ];

  /// A tinted glow for saturated surfaces - the primary FAB, gradient summary
  /// cards, the main call to action. A neutral shadow under a strong colour
  /// reads as dirt; matching the hue keeps it clean.
  static List<BoxShadow> glow(Color color, {double opacity = 0.28}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: color.withValues(alpha: opacity * 0.5),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}
