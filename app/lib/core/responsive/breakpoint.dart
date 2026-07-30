/// The four width tiers the app lays out for.
///
/// Named after the space available, not the hardware. A phone in landscape, a
/// tablet in portrait and a half-width desktop window can all be [medium]; what
/// matters to a layout is how much room it has, never what the device is called.
enum Breakpoint {
  /// < 600dp. Phone portrait.
  compact,

  /// 600-899dp. Phone landscape, small tablet portrait, half-screen window.
  ///
  /// This band is the reason the responsive overhaul happened: the old
  /// three-tier split put its only boundary at 900, so an iPad portrait at
  /// 834dp got the phone build - a four-item bottom bar with POS, Hutang and
  /// Laporan simply absent.
  medium,

  /// 900-1299dp. Landscape tablet.
  expanded,

  /// >= 1300dp. Desktop window.
  large;

  /// True when this tier is [other] or wider.
  ///
  /// Comparing by `index` is safe because the enum is declared narrowest-first,
  /// and the ordering is load-bearing rather than incidental - the doc comments
  /// above say so, and [values] order is part of this type's contract.
  bool atLeast(Breakpoint other) => index >= other.index;

  /// True when this tier is strictly narrower than [other].
  bool below(Breakpoint other) => index < other.index;

  bool get isCompact => this == Breakpoint.compact;
  bool get isMedium => this == Breakpoint.medium;
  bool get isExpanded => this == Breakpoint.expanded;
  bool get isLarge => this == Breakpoint.large;
}

/// Width thresholds, and the mapping from a width to a [Breakpoint].
class AppBreakpoints {
  AppBreakpoints._();

  /// Upper bound of [Breakpoint.compact], exclusive.
  static const double compactMax = 600;

  /// Upper bound of [Breakpoint.medium], exclusive.
  ///
  /// 900 rather than a rounder number because it was the old
  /// `AppDimensions.breakpointMobile`. Reusing the value is what let the four
  /// tiers land without a visual change: `expanded` and `large` together cover
  /// exactly what the old two-way split called tablet-or-desktop, so the new
  /// `medium` band is the only place behaviour moved. See the table in
  /// `modern_breakpoint_scope.dart`.
  static const double mediumMax = 900;

  /// Upper bound of [Breakpoint.expanded], exclusive.
  ///
  /// Likewise the old `AppDimensions.breakpointDesktop`.
  static const double expandedMax = 1300;

  /// Classify a width in logical pixels.
  ///
  /// Widths are clamped at zero rather than asserted: a `LayoutBuilder` can
  /// legitimately report a zero or infinite width mid-layout, and a crash there
  /// would be far worse than reporting [Breakpoint.compact] for one frame.
  static Breakpoint fromWidth(double width) {
    if (!width.isFinite || width <= 0) return Breakpoint.compact;
    if (width < compactMax) return Breakpoint.compact;
    if (width < mediumMax) return Breakpoint.medium;
    if (width < expandedMax) return Breakpoint.expanded;
    return Breakpoint.large;
  }
}
