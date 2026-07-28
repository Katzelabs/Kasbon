import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoint.dart';
import '../../../../core/responsive/modern_breakpoint_scope.dart';

/// Whether the cart is docked open beside the product grid.
///
/// ## Why this is not `setState`
///
/// It was, and that was a bug waiting for RESP_06. A breakpoint change is a
/// parent rebuild: drag the window from 1600 to 700 and the split layout is
/// replaced by the overlay one, taking the `State` object - and the cashier's
/// collapsed cart - with it. Dragging back gave them an expanded cart they had
/// deliberately closed.
///
/// Deliberately *not* `autoDispose`. The whole point is to outlive the widget
/// that reads it; an auto-disposing provider would reset on exactly the tier
/// flip this exists to survive.
final posCartExpandedProvider = StateProvider<bool>((ref) => true);

/// How the POS screen divides the space it is given.
///
/// Pure functions of the measured pane, deliberately: the old code derived its
/// column count from the cart's and the navigation rail's *state*, which meant
/// the grid had to know about two widgets it does not own, and still got the
/// answer wrong whenever the window changed without either of them moving.
/// Both of those are inputs to the pane's width, and the pane's width is the
/// only thing that actually matters here.
class PosLayout {
  PosLayout._();

  /// Widest a product tile grows before the grid adds another column.
  ///
  /// Paired with `SliverGridDelegateWithMaxCrossAxisExtent`, this replaces the
  /// column ladder entirely: 2 columns on a phone, 6 or 7 across a desktop
  /// pane, and every step in between, without a table of breakpoints to keep
  /// in step with the shell.
  static const double productTileMaxExtent = 220;

  /// Vertical room the floating cart summary bar needs above the grid's last
  /// row, in the overlay layout.
  ///
  /// The bar is ~64dp plus its 16dp margins. Combine with
  /// `context.shellBottomInset` rather than folding the navigation bar in
  /// here - the shell owns that number and the two go out of step otherwise.
  static const double cartSummaryBarInset = 96;

  static const double _cartFractionExpanded = 0.30;
  static const double _cartMinExpanded = 320;
  static const double _cartMaxExpanded = 420;

  static const double _cartFractionLarge = 0.28;
  static const double _cartMaxLarge = 480;

  /// Lower clamp at `large`, derived rather than chosen.
  ///
  /// `large` deliberately takes a *smaller* share of a much bigger pane, which
  /// means the two rules disagree at the tier boundary: 0.30 of 1299dp is
  /// 390dp, 0.28 of 1300dp is 364dp. A flat minimum below 390 therefore makes
  /// the cart jump 26dp narrower as the window is dragged one pixel wider -
  /// the class of discontinuity this whole overhaul exists to remove.
  ///
  /// Pinning the floor to where the expanded rule leaves off makes the width
  /// continuous across the boundary and monotonic in the pane's width.
  static const double _cartMinLarge =
      _cartFractionExpanded * AppBreakpoints.expandedMax;

  /// Whether the cart can be docked beside the grid at [tier].
  ///
  /// Below `expanded` it cannot: a 600-899dp pane minus a 320dp cart leaves
  /// under 300dp of grid, which is one column of products. That tier keeps the
  /// summary bar and the modal sheet.
  static bool showsCartSidebar(Breakpoint tier) =>
      tier.atLeast(Breakpoint.expanded);

  /// Width of the docked cart within a pane measured by [layout].
  ///
  /// A share of the pane rather than the old flat 350dp, clamped at both ends:
  /// a proportion alone gives a 700dp cart on an ultrawide monitor, and a fixed
  /// width gives a cart that is 40% of a landscape tablet and 14% of a desktop.
  /// `large` takes a slightly smaller share off a much larger pane, so the cart
  /// still grows in absolute terms while the grid gains most of the extra room.
  static double cartSidebarWidth(BreakpointData layout) {
    if (layout.breakpoint.isLarge) {
      return _clamp(
        layout.width * _cartFractionLarge,
        _cartMinLarge,
        _cartMaxLarge,
      );
    }

    return _clamp(
      layout.width * _cartFractionExpanded,
      _cartMinExpanded,
      _cartMaxExpanded,
    );
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
