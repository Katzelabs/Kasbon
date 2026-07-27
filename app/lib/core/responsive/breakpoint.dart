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
  /// This band is the reason the epic exists: an iPad portrait at 834dp lands
  /// here and currently gets the phone build, because the legacy
  /// `breakpointMobile` threshold is 900.
  medium,

  /// 900-1299dp. Landscape tablet. Matches today's `isTablet` exactly.
  expanded,

  /// >= 1300dp. Desktop window. Matches today's `isDesktop` exactly.
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
  /// Deliberately equal to the legacy `AppDimensions.breakpointMobile`. That
  /// equality is what makes this migration non-breaking: see [Breakpoint] and
  /// the table in `modern_breakpoint_scope.dart`.
  static const double mediumMax = 900;

  /// Upper bound of [Breakpoint.expanded], exclusive.
  ///
  /// Equal to the legacy `AppDimensions.breakpointDesktop`.
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
