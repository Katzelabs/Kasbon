import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_platform.dart';

/// How scrolling behaves across the platforms this app now runs on.
///
/// ## Grab-scroll
///
/// Flutter's default [dragDevices] is touch and stylus only. Dragging with a
/// mouse scrolls nothing, which is invisible on a phone and immediately wrong
/// in a browser: the POS product grid, the long report `CustomScrollView`s and
/// the horizontally-scrolling table all sit still under a pressed mouse button.
/// The wheel still worked, so this reads as a dead widget rather than a missing
/// gesture - the worst kind of bug to notice.
///
/// Adding [PointerDeviceKind.mouse] and [PointerDeviceKind.trackpad] costs
/// nothing on mobile, where neither device kind ever appears.
///
/// ## Physics
///
/// [BouncingScrollPhysics] is an iOS idiom. In a browser it fights the
/// scrollbar - the thumb reaches the end while the content is still travelling -
/// and on Windows or Linux it simply looks wrong. So anything that is not a
/// phone or tablet gets [ClampingScrollPhysics], and native mobile keeps
/// whatever its own platform prescribes.
///
/// This replaces the one hand-rolled `BouncingScrollPhysics` in the widget
/// library, which applied on every platform because it was written when there
/// was only one.
///
/// ## Scrollbars
///
/// [MaterialScrollBehavior] draws a scrollbar on desktop *operating systems*.
/// On the web it asks the same question and hears the browser's underlying OS,
/// so a Chromebook or an Android tablet running the web build gets no scrollbar
/// on a list that may be thousands of rows long. Pointer-first is the condition
/// that actually matters, so that is what this asks.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (AppPlatform.isMobileOs) return super.getScrollPhysics(context);
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (!AppPlatform.isPointerFirst) {
      return super.buildScrollbar(context, child, details);
    }

    // A horizontal scrollbar under a table would sit on top of the last row,
    // so those stay opt-in via ModernDataTable.showHorizontalScrollbar.
    if (details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right) {
      return child;
    }

    return Scrollbar(
      controller: details.controller,
      child: child,
    );
  }
}
