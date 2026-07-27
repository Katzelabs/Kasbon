import 'package:flutter/widgets.dart';

import '../utils/responsive_utils.dart';

/// How wide a column of content is allowed to grow.
///
/// The numbers are reading-comfort limits, not device sizes. Text stops being
/// readable somewhere past ~90 characters a line regardless of how much monitor
/// is available, and a form whose fields span 2000px is harder to use than one
/// that doesn't, not easier.
enum ContentWidth {
  /// 560dp. Single-column forms - login, register, shop profile.
  form(560),

  /// 720dp. Prose and settings lists.
  reading(720),

  /// 1080dp. The default for list and detail screens.
  standard(1080),

  /// 1440dp. Dashboards and multi-column report layouts that genuinely use
  /// the extra room.
  wide(1440),

  /// Unclamped. For screens that manage their own width - the POS grid, a
  /// split view - where an outer clamp would fight the layout underneath.
  full(double.infinity);

  const ContentWidth(this.maxWidth);

  final double maxWidth;
}

/// Centres content, clamps it to a readable width, and applies tier padding.
///
/// Before this, the widget library had no max-width constraint anywhere outside
/// three dialogs, so a 2560px monitor stretched every screen edge to edge.
///
/// ## Re-scoping is the point, not a detail
///
/// This widget publishes a fresh [ModernBreakpointScope] measured at its own
/// *clamped* width. Without that, a 560dp form centred in a 1600dp window would
/// still report `large` to its children, and any child asking "have I got room
/// for three columns?" would hear yes and lay out three columns inside 560dp.
///
/// Clamping the width while leaving the breakpoint describing the window is the
/// subtlest way to get this wrong, which is why it is handled here rather than
/// left to each caller.
class ModernContentColumn extends StatelessWidget {
  /// Maximum width for the content.
  final ContentWidth width;

  /// Horizontal padding. Defaults to the current tier's [contentPadding].
  final double? horizontalPadding;

  /// Vertical padding. Defaults to none, since most callers already pad, or
  /// scroll and need to control their own top and bottom insets.
  final EdgeInsets? verticalPadding;

  final Widget child;

  const ModernContentColumn({
    super.key,
    required this.child,
    this.width = ContentWidth.standard,
    this.horizontalPadding,
    this.verticalPadding,
  });

  /// Shorthand for a single-column form.
  const ModernContentColumn.form({
    super.key,
    required this.child,
    this.horizontalPadding,
    this.verticalPadding,
  }) : width = ContentWidth.form;

  /// Shorthand for prose or a settings list.
  const ModernContentColumn.reading({
    super.key,
    required this.child,
    this.horizontalPadding,
    this.verticalPadding,
  }) : width = ContentWidth.reading;

  /// Shorthand for a dashboard or multi-column report.
  const ModernContentColumn.wide({
    super.key,
    required this.child,
    this.horizontalPadding,
    this.verticalPadding,
  }) : width = ContentWidth.wide;

  @override
  Widget build(BuildContext context) {
    final padding = horizontalPadding ?? context.contentPadding;

    // The scope must sit *inside* the ConstrainedBox. Outside it, its
    // LayoutBuilder measures the incoming constraints - the full window -
    // and republishes exactly the tier this widget exists to narrow.
    final content = ModernBreakpointScope.fromLayout(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding).add(
          verticalPadding ?? EdgeInsets.zero,
        ),
        child: child,
      ),
    );

    if (width == ContentWidth.full) return content;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width.maxWidth),
        child: content,
      ),
    );
  }
}

/// Sliver form of [ModernContentColumn], for the `CustomScrollView` screens.
///
/// A sliver cannot be wrapped in `Center` + `ConstrainedBox` the way a box
/// widget can, so the clamp goes through `SliverConstrainedCrossAxis` and the
/// centring through `SliverCrossAxisGroup`. The behaviour matches the box
/// version, including the re-scope.
class SliverContentColumn extends StatelessWidget {
  final ContentWidth width;
  final double? horizontalPadding;
  final Widget sliver;

  const SliverContentColumn({
    super.key,
    required this.sliver,
    this.width = ContentWidth.standard,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final padding = horizontalPadding ?? context.contentPadding;

    // SliverLayoutBuilder rather than LayoutBuilder: the latter is a box
    // widget and cannot appear in a sliver chain. Its constraints also give
    // the cross-axis extent directly, which is exactly the measurement both
    // the clamp decision and the re-scope need.
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.crossAxisExtent;
        final clamped = width == ContentWidth.full
            ? available
            : available.clamp(0.0, width.maxWidth);

        // Scope built by hand rather than via fromLayout, for the same reason:
        // fromLayout installs a LayoutBuilder. An InheritedWidget is a proxy
        // and passes straight through to the sliver beneath it, so wrapping is
        // safe here.
        final scoped = ModernBreakpointScope(
          data: BreakpointData(
            breakpoint: AppBreakpoints.fromWidth(clamped),
            width: clamped,
            height: constraints.remainingPaintExtent,
            windowBreakpoint: context.windowBreakpoint,
            isPane: context.isInPane,
          ),
          child: SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            sliver: sliver,
          ),
        );

        // Only introduce the group when there is surplus width to absorb.
        // SliverCrossAxisGroup lays out constrained children first, so on a
        // narrow window a 1080 clamp would consume the whole cross axis and
        // leave the expanding spacers with nothing - which throws rather than
        // degrading.
        if (width == ContentWidth.full || available <= width.maxWidth) {
          return scoped;
        }

        return SliverCrossAxisGroup(
          slivers: [
            const SliverCrossAxisExpanded(
                flex: 1, sliver: SliverToBoxAdapter()),
            SliverConstrainedCrossAxis(
              maxExtent: width.maxWidth,
              sliver: scoped,
            ),
            const SliverCrossAxisExpanded(
                flex: 1, sliver: SliverToBoxAdapter()),
          ],
        );
      },
    );
  }
}

/// Spacing tokens for split views and side sheets, used from RESP_05 onward.
///
/// Kept here rather than in `AppDimensions` because they describe responsive
/// layout structure rather than the visual scale.
class ContentLayout {
  ContentLayout._();

  /// Narrowest a master pane may become before the split collapses.
  ///
  /// Below this a list stops being usable - filter chips wrap to three rows and
  /// a product row cannot show name, price and stock together.
  static const double masterPaneMin = 320;

  /// Widest a master pane grows, however much room there is.
  ///
  /// Past this the detail pane is the better home for extra width.
  static const double masterPaneMax = 420;

  /// Master pane's share of a split view, before the min/max clamp.
  static const double masterPaneFraction = 0.32;

  /// Width of a right-edge side sheet at expanded and above.
  static const double sideSheetWidth = 400;

  /// Dialog width by tier. Fixes `ModernDialog.show`, which currently wraps
  /// its child in a bare `Dialog` with no max width at all.
  static const double dialogCompact = 420;
  static const double dialogMedium = 560;
  static const double dialogLarge = 640;
}
