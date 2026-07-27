import 'package:flutter/widgets.dart';

import 'breakpoint.dart';

/// What the nearest enclosing [ModernBreakpointScope] measured.
@immutable
class BreakpointData {
  /// Tier of the space this widget actually has.
  final Breakpoint breakpoint;

  /// Width of that space, in logical pixels.
  final double width;

  /// Height of that space, in logical pixels.
  final double height;

  /// Tier of the whole window, regardless of the space this widget has.
  ///
  /// **For shell chrome only** - the navigation rail, the app bar, anything
  /// deciding what the window as a whole should look like. A screen or pane
  /// that reads this instead of [breakpoint] is reintroducing the bug this
  /// class exists to fix.
  final Breakpoint windowBreakpoint;

  /// Whether this scope measures a pane rather than the full content area.
  ///
  /// Lets a widget render pane-appropriate chrome - no back button, a close
  /// control instead - without threading a flag down through constructors.
  final bool isPane;

  const BreakpointData({
    required this.breakpoint,
    required this.width,
    required this.height,
    required this.windowBreakpoint,
    this.isPane = false,
  });

  @override
  bool operator ==(Object other) =>
      other is BreakpointData &&
      other.breakpoint == breakpoint &&
      other.width == width &&
      other.height == height &&
      other.windowBreakpoint == windowBreakpoint &&
      other.isPane == isPane;

  @override
  int get hashCode =>
      Object.hash(breakpoint, width, height, windowBreakpoint, isPane);

  @override
  String toString() => 'BreakpointData($breakpoint, ${width}x$height, '
      'window: $windowBreakpoint, pane: $isPane)';
}

/// Publishes the measured size of a region so descendants can lay out for the
/// space they actually have, rather than for the size of the window.
///
/// ## Why this exists
///
/// Before this, every responsive decision in the app read
/// `MediaQuery.of(context).size.width` - the *window*. That is correct only
/// while every screen is full-width. The moment a screen becomes a 400dp master
/// pane inside a 1600dp window, it asks how wide the window is, hears "1600",
/// and renders a desktop layout into a phone-width column.
///
/// ## Why an InheritedWidget rather than a MediaQuery override
///
/// Overriding `MediaQuery.size` at the pane boundary would redirect every
/// existing call site in one line, which is tempting. It was rejected: it makes
/// `MediaQuery` lie about genuinely screen-level things. `viewInsets` (keyboard
/// height, which `product_list_screen` does arithmetic on) and safe-area padding
/// would then describe a pane that has neither. And it buys nothing where it
/// would matter most - Flutter's `Dialog` and `showModalBottomSheet` read
/// `MediaQuery` from the *root* navigator context, so they are unaffected either
/// way.
///
/// Passing a `Breakpoint` down through constructors was also rejected: no
/// incremental migration path, and no answer for router-built widgets.
///
/// ## Where scopes are installed
///
/// 1. App root, so the lookup is never null even outside the shell.
/// 2. The shell's content area, inside the navigation rail. This is the
///    highest-leverage one: with a 280dp rail on a 1400dp window, content is
///    1120dp - `expanded`, not `large`.
/// 3. Each split pane (RESP_07).
/// 4. [ModernContentColumn], which re-scopes to its own clamped width.
class ModernBreakpointScope extends InheritedWidget {
  final BreakpointData data;

  const ModernBreakpointScope({
    super.key,
    required this.data,
    required super.child,
  });

  /// The nearest scope, or null when there is none.
  ///
  /// Prefer the `context.breakpoint` extension in `responsive_utils.dart`,
  /// which falls back to `MediaQuery` so it can never return null.
  static BreakpointData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ModernBreakpointScope>()
        ?.data;
  }

  /// Reads the scope without subscribing to changes.
  ///
  /// For callbacks and `initState`, where creating a dependency would be wrong
  /// or would throw. Layout code wants [maybeOf].
  static BreakpointData? readOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<ModernBreakpointScope>()
        ?.data;
  }

  @override
  bool updateShouldNotify(ModernBreakpointScope oldWidget) =>
      data != oldWidget.data;

  /// Measures [child]'s incoming constraints and publishes them.
  ///
  /// [isPane] marks the region as a split pane. [inheritWindow] keeps the
  /// enclosing scope's `windowBreakpoint`, so shell chrome nested inside a
  /// narrow pane still knows how big the window is; at the app root there is no
  /// enclosing scope, so the measured width is the window by definition.
  static Widget fromLayout({
    Key? key,
    bool isPane = false,
    bool inheritWindow = true,
    required Widget child,
  }) {
    return _BreakpointLayoutScope(
      key: key,
      isPane: isPane,
      inheritWindow: inheritWindow,
      child: child,
    );
  }
}

class _BreakpointLayoutScope extends StatelessWidget {
  final bool isPane;
  final bool inheritWindow;
  final Widget child;

  const _BreakpointLayoutScope({
    super.key,
    required this.isPane,
    required this.inheritWindow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Read the parent scope outside the builder: this is about which window we
    // are in, which cannot change as a result of our own constraints.
    final parent =
        inheritWindow ? ModernBreakpointScope.maybeOf(context) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded width means an ancestor is measuring intrinsic size
        // rather than laying us out - a horizontal scroll view, say. Falling
        // back to the window is the only defensible reading, and is what the
        // old MediaQuery-based code did everywhere anyway.
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        final breakpoint = AppBreakpoints.fromWidth(width);

        return ModernBreakpointScope(
          data: BreakpointData(
            breakpoint: breakpoint,
            width: width,
            height: height,
            // No parent scope means we are the outermost one, so what we
            // measured is the window.
            windowBreakpoint: parent?.windowBreakpoint ?? breakpoint,
            // Panes stay panes for everything below them.
            isPane: isPane || (parent?.isPane ?? false),
          ),
          child: child,
        );
      },
    );
  }
}
