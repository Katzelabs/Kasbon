import 'package:flutter/material.dart';

import '../../config/theme/app_dimensions.dart';
import '../responsive/breakpoint.dart';
import '../responsive/modern_breakpoint_scope.dart';

export '../responsive/breakpoint.dart';
export '../responsive/master_detail_scaffold.dart';
export '../responsive/modern_breakpoint_scope.dart';
export '../responsive/modern_content_column.dart';
export '../responsive/modern_shell_insets.dart';

/// Device type classification based on screen width.
@Deprecated(
  'Use Breakpoint. DeviceType has three tiers and cannot express the 600-899dp '
  'band where an iPad portrait lives. Removed in RESP_10.',
)
enum DeviceType { mobile, tablet, desktop }

/// Utility class for responsive design breakpoint detection.
///
/// Superseded by [Breakpoint] and the [ResponsiveContext] extension below.
/// Retained so the ~24 files importing this path keep compiling; removed in
/// RESP_10.
class ResponsiveUtils {
  ResponsiveUtils._();

  /// Get the device type based on screen width
  @Deprecated('Use context.breakpoint. Removed in RESP_10.')
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppDimensions.breakpointMobile) return DeviceType.mobile;
    if (width < AppDimensions.breakpointDesktop) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Check if current device is mobile (< 900dp)
  ///
  /// Note the threshold is 900, not the 600 a Material breakpoint would use.
  /// An iPad in portrait (834dp) therefore counts as mobile here.
  @Deprecated('Use context.isCompact / context.isMedium. Removed in RESP_10.')
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppDimensions.breakpointMobile;

  /// Check if current device is tablet (>= 900dp and < 1300dp)
  @Deprecated('Use context.isExpanded. Removed in RESP_10.')
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppDimensions.breakpointMobile &&
        width < AppDimensions.breakpointDesktop;
  }

  /// Check if current device is desktop (>= 1300dp)
  @Deprecated('Use context.isLarge. Removed in RESP_10.')
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppDimensions.breakpointDesktop;

  /// Check if current device is tablet or desktop (>= 900dp)
  @Deprecated(
    'Use context.isAtLeast(Breakpoint.expanded). Removed in RESP_10.',
  )
  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppDimensions.breakpointMobile;

  /// Get the number of grid columns based on device type
  @Deprecated('Use context.gridColumns(). Removed in RESP_10.')
  static int getGridColumns(BuildContext context,
      {int mobile = 2, int tablet = 3, int desktop = 4}) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppDimensions.breakpointMobile) return mobile;
    if (width < AppDimensions.breakpointDesktop) return tablet;
    return desktop;
  }

  /// Get horizontal padding based on device type
  @Deprecated('Use context.contentPadding. Removed in RESP_10.')
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppDimensions.breakpointMobile) return AppDimensions.spacing16;
    if (width < AppDimensions.breakpointDesktop) return AppDimensions.spacing24;
    return AppDimensions.spacing32;
  }
}

/// Responsive queries on a [BuildContext].
///
/// ## Two families, deliberately
///
/// The **new** members ([breakpoint], [isCompact] … [responsive]) read the
/// nearest [ModernBreakpointScope] - the space this widget actually occupies -
/// and fall back to the window only when no scope is in play.
///
/// The **deprecated** members ([isMobile], [isTablet], [isDesktop],
/// [isTabletOrDesktop], [deviceType], [horizontalPadding]) keep reading the
/// *window*, exactly as they did before this file was rewritten.
///
/// That split is intentional and is what makes RESP_03 a zero-visual-change
/// commit. Had the legacy getters been repointed at the scope, every screen
/// inside the shell would silently start measuring the content area instead of
/// the window - and since the shell's rail is 80dp wide, a window of 900-980dp
/// would put content below the 900 threshold and flip ~24 screens from their
/// tablet layout to their phone layout in that band. Correct in principle,
/// but a regression today, and the epic's rule is that nothing which works
/// today may regress.
///
/// So screens migrate onto the scope-aware API deliberately, one at a time, in
/// RESP_04 onward. The forwarders are deleted in RESP_10, by which point
/// nothing should still be calling them.
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

  // There is deliberately no scope-aware `gridColumns`. A column count is just
  // a tier-dependent value, and `responsive<int>(compact: 2, expanded: 3)`
  // expresses it without a second, near-identical API to keep in step.

  // ---------------------------------------------------------------------
  // Deprecated: window-based, preserving pre-RESP_03 behaviour exactly.
  // ---------------------------------------------------------------------

  /// Check if current device is mobile
  @Deprecated('Use isCompact / isMedium. Removed in RESP_10.')
  bool get isMobile =>
      MediaQuery.sizeOf(this).width < AppDimensions.breakpointMobile;

  /// Check if current device is tablet
  @Deprecated('Use isExpanded. Removed in RESP_10.')
  bool get isTablet {
    final width = MediaQuery.sizeOf(this).width;
    return width >= AppDimensions.breakpointMobile &&
        width < AppDimensions.breakpointDesktop;
  }

  /// Check if current device is desktop
  @Deprecated('Use isLarge. Removed in RESP_10.')
  bool get isDesktop =>
      MediaQuery.sizeOf(this).width >= AppDimensions.breakpointDesktop;

  /// Check if current device is tablet or desktop
  @Deprecated('Use isAtLeast(Breakpoint.expanded). Removed in RESP_10.')
  bool get isTabletOrDesktop =>
      MediaQuery.sizeOf(this).width >= AppDimensions.breakpointMobile;

  /// Get responsive grid columns
  ///
  /// Window-based, like the rest of this deprecated family. New code wants
  /// `context.responsive<int>(compact: 2, expanded: 3, large: 4)`, which reads
  /// the space the grid actually occupies.
  @Deprecated('Use responsive<int>(...). Removed in RESP_10.')
  int gridColumns({int mobile = 2, int tablet = 3, int desktop = 4}) {
    final width = MediaQuery.sizeOf(this).width;
    if (width < AppDimensions.breakpointMobile) return mobile;
    if (width < AppDimensions.breakpointDesktop) return tablet;
    return desktop;
  }

  /// Get the current device type
  @Deprecated('Use breakpoint. Removed in RESP_10.')
  DeviceType get deviceType {
    final width = MediaQuery.sizeOf(this).width;
    if (width < AppDimensions.breakpointMobile) return DeviceType.mobile;
    if (width < AppDimensions.breakpointDesktop) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Get responsive horizontal padding
  @Deprecated('Use contentPadding. Removed in RESP_10.')
  double get horizontalPadding {
    final width = MediaQuery.sizeOf(this).width;
    if (width < AppDimensions.breakpointMobile) return AppDimensions.spacing16;
    if (width < AppDimensions.breakpointDesktop) return AppDimensions.spacing24;
    return AppDimensions.spacing32;
  }
}
