import 'package:flutter/widgets.dart';

import '../../../core/platform/app_platform.dart';

/// Builds a widget that knows whether a pointer is currently over it.
///
/// [isHovered] is always false on a touch-first platform - see
/// [ModernHoverBuilder] for why that is a deliberate short-circuit rather than
/// a missing feature.
typedef ModernHoverWidgetBuilder = Widget Function(
  BuildContext context,
  bool isHovered,
  Widget? child,
);

/// Tracks pointer hover and sets a pointer cursor, for the components that
/// need a hover state of their own.
///
/// ## Why this exists
///
/// `InkWell` already gives hover and a cursor, and where a component uses one
/// it needs nothing from this file. The gap is everything that does not:
/// a `GestureDetector` wrapped around a card for long-press, a table row that
/// paints its own background, a paginator button that wants a border tint
/// rather than an ink splash. Before this, a desktop user moving the mouse
/// across the product grid got no feedback at all - nothing on the page
/// admitted to being clickable.
///
/// ## Short-circuiting on touch platforms
///
/// On a touch-first platform the builder is called once with `false` and no
/// [MouseRegion] is installed. That is not only a saving - a stale hover is a
/// real bug on touch. A finger that lifts outside the widget never sends an
/// exit event, so the highlight sticks until something else rebuilds it.
///
/// The consequence for tests: `flutter test` reports
/// `TargetPlatform.android`, so a hover test must set
/// `debugDefaultTargetPlatformOverride` to a desktop platform first.
///
/// ## Usage
///
/// ```dart
/// ModernHoverBuilder(
///   child: expensiveSubtree,           // built once, not per hover change
///   builder: (context, isHovered, child) => AnimatedContainer(
///     duration: ModernHoverBuilder.duration,
///     color: isHovered ? AppColors.surfaceVariant : AppColors.surface,
///     child: child,
///   ),
/// )
/// ```
class ModernHoverBuilder extends StatefulWidget {
  const ModernHoverBuilder({
    super.key,
    required this.builder,
    this.child,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
    this.onHoverChanged,
  });

  /// Builds the widget for the current hover state.
  final ModernHoverWidgetBuilder builder;

  /// Subtree that does not depend on hover, passed back to [builder].
  ///
  /// Anything expensive belongs here so it survives a hover change untouched.
  final Widget? child;

  /// Whether hover tracking applies at all.
  ///
  /// Pass `false` for a disabled control: it keeps the default cursor and never
  /// highlights, which is the whole point of looking disabled.
  final bool enabled;

  /// Cursor shown while the pointer is inside.
  final MouseCursor cursor;

  /// Called when the hover state flips, for callers that also need to react
  /// outside the returned subtree.
  final ValueChanged<bool>? onHoverChanged;

  /// How long a hover transition should take.
  ///
  /// Short enough to feel attached to the pointer; a 200ms+ fade reads as lag
  /// when the mouse is sweeping across a grid.
  static const Duration duration = Duration(milliseconds: 120);

  @override
  State<ModernHoverBuilder> createState() => _ModernHoverBuilderState();
}

class _ModernHoverBuilderState extends State<ModernHoverBuilder> {
  bool _isHovered = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  void didUpdateWidget(ModernHoverBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A control that becomes disabled under a resting pointer would otherwise
    // keep its highlight, since no exit event is coming.
    if (!widget.enabled && _isHovered) {
      _isHovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !AppPlatform.isPointerFirst) {
      return widget.builder(context, false, widget.child);
    }

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: widget.builder(context, _isHovered, widget.child),
    );
  }
}

/// Wraps [child] in a click cursor without tracking hover state.
///
/// For the case the grid items hit: a bare `GestureDetector` handles the tap,
/// the visual affordance already exists, and all that is missing is the pointer
/// turning into a hand. `MouseRegion` alone would do it, but naming it says why.
class ModernClickCursor extends StatelessWidget {
  const ModernClickCursor({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// Whether the target is currently clickable.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !AppPlatform.isPointerFirst) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: child,
    );
  }
}
