import 'package:flutter/widgets.dart';

import '../../config/theme/app_dimensions.dart';
import 'breakpoint.dart';

/// How much space the app shell's own chrome takes out of a screen's body.
///
/// ## The problem this replaces
///
/// The shell sets `extendBody: true` on compact, so the bottom navigation bar
/// floats over the content rather than displacing it. Every scrollable screen
/// therefore has to add the bar's height to its own bottom padding, or its last
/// row sits underneath the bar and cannot be reached.
///
/// Twenty-five sites did that by hand, each spelling out some variant of:
///
/// ```dart
/// final bottomPadding = context.isMobile
///     ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
///     : AppDimensions.spacing16;
/// ```
///
/// Three things went wrong with that, all of them predictable:
///
/// 1. **Two sites forgot the guard entirely**, though only one of them was a
///    live bug. `debt_list_screen` has no mobile/tablet branch at all, so its
///    unconditional `bottomNavHeight + spacing32` applied at every width and
///    left 112px of dead space below the list on tablet. `dashboard_screen`'s
///    unguarded padding sits inside `_MobileDashboard`, which only renders
///    when the shell shows a bottom bar - harmless today, but it would break
///    the moment RESP_04 gives the medium tier a rail.
/// 2. **One invented its own constant** - `pos_screen` hard-codes `80.0`
///    rather than reading `AppDimensions.bottomNavHeight`, so the two drift
///    independently.
/// 3. **The count grew silently.** It was 19 when this work was planned and 25
///    by the time it started; the reports feature added six without anyone
///    noticing. `test/architecture_test.dart` now fails the build on a
///    twenty-sixth.
///
/// This matters beyond tidiness: RESP_04 gives the medium tier a navigation
/// rail instead of a bottom bar. Every unconverted site would then over-pad by
/// 80px on any 600-899dp screen.
///
/// ## Reading the window, deliberately
///
/// [shellBottomInset] asks how the *window* is laid out, not how much room the
/// calling widget has. A screen inside a 400dp split pane on a 1600dp desktop
/// still has no bottom bar beneath it, because the shell chose a rail for the
/// window. Using the container tier here would put phantom padding under every
/// narrow pane.
///
/// This is the exception the `windowBreakpoint` doc comment refers to, and one
/// of the few places where reading the window is the correct answer.
extension ModernShellInsets on BuildContext {
  /// Height the shell's bottom navigation covers, or zero when it shows none.
  ///
  /// Add this to a scroll view's bottom padding. Combine with the desired
  /// spacing rather than replacing it:
  ///
  /// ```dart
  /// padding: EdgeInsets.only(
  ///   bottom: AppDimensions.spacing16 + context.shellBottomInset,
  /// )
  /// ```
  double get shellBottomInset {
    // Deliberately the window, not the container - see the class doc above.
    // Uses MediaQuery rather than the breakpoint scope for the same reason:
    // this must not change when a pane scope narrows the measured width.
    //
    // The threshold is `compact`, and must stay in step with the tier the shell
    // draws a bottom bar for. RESP_04 moved it down from the legacy 900: the
    // medium tier now gets a navigation rail, so a 600-899dp window has no bar
    // to pad around and every screen would otherwise reserve 80px of dead
    // space beneath itself.
    final width = MediaQuery.sizeOf(this).width;
    return AppBreakpoints.fromWidth(width).isCompact
        ? AppDimensions.bottomNavHeight
        : 0.0;
  }

  /// Whether the shell is currently showing a bottom navigation bar.
  ///
  /// For deciding where a floating action button sits, or whether a screen
  /// needs its own bottom affordance at all.
  bool get hasShellBottomNav => shellBottomInset > 0;
}
