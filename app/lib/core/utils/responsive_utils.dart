import 'package:flutter/material.dart';

import '../../config/theme/app_dimensions.dart';
import '../responsive/breakpoint.dart';
import '../responsive/modern_breakpoint_scope.dart';

export '../responsive/breakpoint.dart';
export '../responsive/master_detail_scaffold.dart';
export '../responsive/modern_breakpoint_scope.dart';
export '../responsive/modern_content_column.dart';
export '../responsive/modern_shell_insets.dart';

/// Responsive queries on a [BuildContext].
///
/// Every member here reads the nearest [ModernBreakpointScope] - the space this
/// widget actually occupies - and falls back to the window only when no scope is
/// in play. That distinction is the point: a 400dp pane inside a 1600dp window
/// is `compact`, and a layout that asked the window instead would render its
/// desktop form in a column too narrow to hold it.
///
/// A window-based family (`isMobile`, `isTablet`, `isDesktop`,
/// `isTabletOrDesktop`, `deviceType`, `gridColumns`, `horizontalPadding`, and
/// the `ResponsiveUtils` statics) existed alongside this one through RESP_03-09b
/// so screens could migrate one at a time. It was deleted in RESP_10, once
/// nothing called it. Reach for [windowBreakpoint] if you genuinely need the
/// window - shell chrome does, screens do not.
extension ResponsiveContext on BuildContext {
  /// Everything the nearest scope measured.
  ///
  /// Falls back to the window when no scope is present, so this is never null
  /// even in a widget test that pumps a bare widget.
  BreakpointData get breakpointData {
    final scope = ModernBreakpointScope.maybeOf(this);
    if (scope != null) return scope;

    final size = MediaQuery.sizeOf(this);
    final breakpoint = AppBreakpoints.fromWidth(size.width);
    return BreakpointData(
      breakpoint: breakpoint,
      width: size.width,
      height: size.height,
      windowBreakpoint: breakpoint,
    );
  }

  /// Tier of the space this widget actually has.
  Breakpoint get breakpoint => breakpointData.breakpoint;

  /// Width of that space, in logical pixels.
  double get availableWidth => breakpointData.width;

  /// Tier of the whole window.
  ///
  /// **Shell chrome only.** A screen or pane reading this instead of
  /// [breakpoint] reintroduces the bug the scope exists to fix.
  Breakpoint get windowBreakpoint => breakpointData.windowBreakpoint;

  /// Whether this widget is inside a split pane.
  bool get isInPane => breakpointData.isPane;

  bool get isCompact => breakpoint.isCompact;
  bool get isMedium => breakpoint.isMedium;
  bool get isExpanded => breakpoint.isExpanded;
  bool get isLarge => breakpoint.isLarge;

  /// True when the available space is [tier] or wider.
  bool isAtLeast(Breakpoint tier) => breakpoint.atLeast(tier);

  /// True when the available space is narrower than [tier].
  bool isBelow(Breakpoint tier) => breakpoint.below(tier);

  /// Pick a value for the current tier, cascading upward.
  ///
  /// Only [compact] is required; each wider tier falls back to the nearest
  /// narrower one supplied. So `responsive(compact: 1, expanded: 3)` yields
  /// 1, 1, 3, 3 across the four tiers - a layout opts into the tiers it
  /// actually cares about instead of restating every one.
  T responsive<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? large,
  }) {
    switch (breakpoint) {
      case Breakpoint.compact:
        return compact;
      case Breakpoint.medium:
        return medium ?? compact;
      case Breakpoint.expanded:
        return expanded ?? medium ?? compact;
      case Breakpoint.large:
        return large ?? expanded ?? medium ?? compact;
    }
  }

  /// Horizontal padding appropriate to the current tier.
  double get contentPadding => responsive<double>(
        compact: AppDimensions.spacing16,
        medium: AppDimensions.spacing20,
        expanded: AppDimensions.spacing24,
        large: AppDimensions.spacing32,
      );

  // There is deliberately no `gridColumns`. A column count is just a
  // tier-dependent value, and `responsive<int>(compact: 2, expanded: 3)`
  // expresses it without a second, near-identical API to keep in step. When the
  // count should follow an exact width rather than a tier, measure it - see the
  // `SliverLayoutBuilder` in `product_list_screen.dart`.
}
