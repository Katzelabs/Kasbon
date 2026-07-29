import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';

/// Layout primitives shared by the seven report screens.
///
/// ## Why column counts are derived from width, not from the tier
///
/// [ModernContentColumn] re-scopes to its own *clamped* width, so a screen
/// wrapped in `ContentWidth.standard` reports `expanded` at every window size
/// past 1080dp - it can never report `large`, because the column is never that
/// wide. A grid keyed to `context.isLarge` inside such a column would therefore
/// never take its widest form, and the bug would look like "the rule doesn't
/// work" rather than "the rule can't fire".
///
/// Asking how many tiles of a given minimum width fit sidesteps that entirely,
/// and it is the honest question anyway: what a stat card needs is 170dp, not
/// a particular class of device.
///
/// [ReportSplitRow] is the exception and keys on a tier deliberately - see its
/// doc comment.

/// Lays [children] out in as many equal-width columns as fit.
///
/// Each tile is re-scoped with [ModernBreakpointScope.fromLayout] so anything
/// inside it - a chart above all - measures the tile rather than the screen.
class ReportTileGrid extends StatelessWidget {
  /// Tiles, in priority order. They flow left to right, then wrap.
  final List<Widget> children;

  /// Narrowest a tile may become before a column is dropped.
  final double minTileWidth;

  /// Ceiling on the column count, for content that stops reading well past a
  /// certain density however much room there is.
  final int maxColumns;

  final double spacing;
  final double runSpacing;

  const ReportTileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 240,
    this.maxColumns = 4,
    this.spacing = AppDimensions.spacing12,
    this.runSpacing = AppDimensions.spacing12,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded width means an ancestor is measuring intrinsics; one
        // tile per row is the only answer that cannot overflow.
        final width =
            constraints.hasBoundedWidth ? constraints.maxWidth : minTileWidth;

        final columns = _columnsFor(width);
        final tileWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: tileWidth,
                child: ModernBreakpointScope.fromLayout(child: child),
              ),
          ],
        );
      },
    );
  }

  int _columnsFor(double width) {
    final fit = ((width + spacing) / (minTileWidth + spacing)).floor();
    return fit.clamp(1, math.min(maxColumns, children.length));
  }
}

/// A dashboard grid: [children] distributed across N columns, each column a
/// stack of full-width cards.
///
/// Deliberately not a `GridView`. Report blocks have wildly different heights -
/// a comparison card is 180dp, a heatmap 400dp - and a fixed-extent grid would
/// either clip the tall ones or leave a screen of white space under the short
/// ones. Columns of stacked cards let each block keep its natural height.
///
/// Children are dealt round-robin rather than filled column by column, so the
/// order they are written in stays the reading order left to right.
class ReportDashboardGrid extends StatelessWidget {
  final List<Widget> children;

  /// Narrowest a column may become. Below this, charts start losing their axis
  /// labels, so the grid drops to fewer columns instead.
  final double minColumnWidth;

  final int maxColumns;
  final double spacing;

  const ReportDashboardGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 400,
    this.maxColumns = 3,
    this.spacing = AppDimensions.spacing20,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth ? constraints.maxWidth : minColumnWidth;

        final columns = _columnsFor(width);
        if (columns <= 1) return _stack(children);

        // Round-robin, so children[0] heads the first column, children[1] the
        // second, and so on.
        final buckets = List.generate(columns, (_) => <Widget>[]);
        for (var i = 0; i < children.length; i++) {
          buckets[i % columns].add(children[i]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(
                // Each column publishes its own width: a chart in a 460dp cell
                // of a 1440dp window has 460dp, and must lay out for that.
                child: ModernBreakpointScope.fromLayout(
                  child: _stack(buckets[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _stack(List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          items[i],
        ],
      ],
    );
  }

  int _columnsFor(double width) {
    final fit = ((width + spacing) / (minColumnWidth + spacing)).floor();
    return fit.clamp(1, math.min(maxColumns, children.length));
  }
}

/// Two blocks side by side once the container reaches [splitAt], stacked below
/// it.
///
/// This one keys on the tier rather than on a pixel minimum, because the
/// decision is editorial rather than mechanical: a chart beside its own detail
/// list is a desktop reading of the screen, and the point at which it becomes
/// the better reading is a judgement about the whole layout, not about how many
/// pixels either half needs.
class ReportSplitRow extends StatelessWidget {
  /// The block that gets the larger share.
  final Widget primary;

  final Widget secondary;

  final int primaryFlex;
  final int secondaryFlex;

  /// Tier at which the two go side by side. Measured on the container, so a
  /// split view or a dashboard cell narrows it correctly.
  final Breakpoint splitAt;

  final double spacing;

  const ReportSplitRow({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 2,
    this.secondaryFlex = 1,
    this.splitAt = Breakpoint.large,
    this.spacing = AppDimensions.spacing20,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isAtLeast(splitAt)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          SizedBox(height: spacing),
          secondary,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: primaryFlex,
          child: ModernBreakpointScope.fromLayout(child: primary),
        ),
        SizedBox(width: spacing),
        Expanded(
          flex: secondaryFlex,
          child: ModernBreakpointScope.fromLayout(child: secondary),
        ),
      ],
    );
  }
}

/// Caps how wide a chart may grow and publishes the capped width to it.
///
/// Two jobs, and they have to happen in this order. The cap is the point: seven
/// bars spread across 2000dp is not a chart, it is a row of distant sticks, and
/// a 24-column heatmap stretched to a desktop window has cells the size of
/// playing cards. The scope must then sit *inside* the cap, or the chart reads
/// the width it was offered rather than the width it was given - the same
/// mistake [ModernContentColumn] documents at screen level.
class ReportChartFrame extends StatelessWidget {
  /// Widest the chart may become, whatever room it is offered.
  final double maxWidth;

  final Widget child;

  const ReportChartFrame({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ModernBreakpointScope.fromLayout(child: child),
      ),
    );
  }
}

/// Width caps for the report charts, kept together so the family stays
/// visually coherent rather than each chart inventing its own ceiling.
class ReportChartWidths {
  ReportChartWidths._();

  /// Seven bars. Past this they are further apart than they are wide.
  static const double dayOfWeekBar = 640;

  /// Up to ~31 daily bars, so it earns more room than the weekday chart.
  static const double dailyBar = 960;

  /// Donut plus legend side by side.
  static const double pie = 880;

  /// A line chart genuinely reads better wide - this is generous on purpose.
  static const double trendLine = 1200;

  /// 24 columns at the maximum legible cell size, plus the weekday gutter.
  static const double heatmap = 1120;
}
