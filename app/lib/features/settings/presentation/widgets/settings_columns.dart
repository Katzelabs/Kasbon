import 'package:flutter/material.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';

/// The settings groups: one column on a phone, two side by side once there is
/// room for both.
///
/// ## Why the hub splits but a row never does
///
/// A settings row is prose-shaped - an icon, a title, a one-line subtitle - and
/// it gets no easier to read for being 1000dp wide. That is why the hub was
/// clamped to reading width in the first place, and none of that changes here.
/// What does change is what happens to the *space beside* it: on a landscape
/// tablet a single 720dp ribbon leaves half the window empty and still pushes
/// the last two groups below the fold. Splitting the groups - not the rows -
/// keeps every row at a width it reads well at and puts the whole hub on one
/// screen.
///
/// ## Why the split is written out rather than dealt
///
/// Distributing the groups round-robin would be shorter and would balance the
/// column heights better, but the two columns mean something: [start] is what a
/// shop owner configures, [end] is what the app is and who is signed in.
/// Alternating would file "Hapus Akun" beside "Profil Toko" for no reason other
/// than the order the groups happen to be declared in.
///
/// Below [splitAt] the two lists are concatenated, so the single-column reading
/// order is exactly `start` then `end` - the order the hub has always had.
class SettingsColumns extends StatelessWidget {
  const SettingsColumns({
    super.key,
    required this.start,
    required this.end,
    this.splitAt = Breakpoint.expanded,
    this.spacing = AppDimensions.spacing24,
  });

  /// Groups for the leading column, and the first half of the single column.
  final List<Widget> start;

  /// Groups for the trailing column, and the second half of the single column.
  final List<Widget> end;

  /// Tier at which the columns separate.
  ///
  /// [Breakpoint.expanded] rather than [Breakpoint.medium]: an iPad in portrait
  /// is 834dp, which halves into two 380dp columns once the gutters are paid
  /// for, and a settings row that narrow starts ellipsing the subtitles that
  /// are the whole reason the rows have one.
  ///
  /// Measured on the container, so a split pane narrows it correctly.
  final Breakpoint splitAt;

  /// Gap between groups, and between the two columns.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!context.isAtLeast(splitAt)) {
      return _stack([...start, ...end]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Each column publishes its own width. Nothing in a settings group
        // reads the tier today, but a group that grows a chart or a two-up
        // summary must measure the column it is in, not the hub.
        Expanded(
          child: ModernBreakpointScope.fromLayout(child: _stack(start)),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: ModernBreakpointScope.fromLayout(child: _stack(end)),
        ),
      ],
    );
  }

  Widget _stack(List<Widget> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          groups[i],
        ],
      ],
    );
  }
}
