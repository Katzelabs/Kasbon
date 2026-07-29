import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
// Re-exports breakpoint.dart, modern_breakpoint_scope.dart and
// modern_content_column.dart along with the context extension, the same way
// ModernContentColumn reaches for them.
import '../utils/responsive_utils.dart';

/// Turns a list route into a two-pane master/detail view on wide windows,
/// without touching the route table.
///
/// ## Why the route table stays as it is
///
/// The obvious shape - a nested `ShellRoute` per feature - was rejected. To
/// make `/products/:id` a child of a per-feature shell, either the list becomes
/// a *sibling* of the detail (which destroys the URL-nesting back-stack
/// synthesis documented on `AppRouter.router`), or `/products` becomes both the
/// shell and its own index, which changes the URL shape. Both are pinned by
/// `route_url_behavior_test.dart` and `app_router_test.dart`.
///
/// So the `ShellRoute`, the nesting and `go` semantics are all unchanged. Two
/// things happen instead:
///
/// 1. The **list** route's child is wrapped in this widget, which reads the
///    full URI from [GoRouterState] - every match in the stack carries the full
///    location, which is how `ModernAppShell` already highlights nested routes -
///    parses the selected id out of it, and renders the detail beside the
///    master when there is room.
/// 2. The **detail** route's child is wrapped in [SplitDetailRoute], which
///    collapses to nothing while the pane is already showing it, and its page
///    is made non-opaque so the list underneath keeps painting.
///
/// ## Read the tier in build, never in pageBuilder
///
/// A route's `pageBuilder` runs when go_router rebuilds the route table, which
/// a window resize does *not* do. Deciding the split there would mean dragging
/// a window from 1400 to 700 with a detail open leaves a permanently blank
/// detail: the pane stops rendering it and the page it was built into is still
/// the empty one. Both this widget and [SplitDetailRoute] therefore read
/// [isSplitActive] in `build`, where the breakpoint scope's `LayoutBuilder`
/// makes it resize-live.
///
/// ## The panes are scopes
///
/// Each pane installs a `ModernBreakpointScope(isPane: true)` measured at its
/// own width, so each side lays out for the room it actually has rather than
/// for the window it happens to be inside. That is what lets the list gain and
/// lose grid columns purely from the panel's width, with no column ladder that
/// has to know the panel exists.
///
/// ## Geometry
///
/// The list keeps the room and the detail docks against the trailing edge at
/// [ContentLayout.detailPaneWidth] - the same rule the POS screen gives its
/// cart, so two docked panels in one window are the same width.
class MasterDetailScaffold extends StatelessWidget {
  const MasterDetailScaffold({
    super.key,
    required this.master,
    required this.basePath,
    required this.selectionParser,
    required this.detailBuilder,
    this.placeholderBuilder,
  });

  /// The list screen. Rendered alone when there is no room to split.
  final Widget master;

  /// Where the master lives - `/products`. Used as the fallback close target
  /// when there is no route to pop, which only happens if something reached
  /// the detail without `go` synthesising a parent stack.
  final String basePath;

  /// Extracts the selected id from the current URI, or null when the URI
  /// addresses no detail. Given the *full* location, so it can distinguish
  /// `/products/:id`, `/products/:id/edit` and `/products/add`.
  final String? Function(Uri uri) selectionParser;

  /// Builds the pane contents for [id]. Handed the full URI too, so a feature
  /// with more than one detail route (view vs edit) can pick between them.
  final Widget Function(BuildContext context, Uri uri, String id) detailBuilder;

  /// What the detail pane shows when nothing is selected.
  final WidgetBuilder? placeholderBuilder;

  /// The rule between the two panes, and the inset it costs the panel.
  ///
  /// One logical pixel, drawn over the panel's leading edge. Named because two
  /// places have to agree on it - the decoration that paints it and the padding
  /// that keeps content clear of it - and because the geometry tests measure
  /// the panel to within it.
  static const double dividerWidth = 1;

  /// The narrowest tier that gets two panes.
  ///
  /// At `expanded` (900dp) the panel takes its 320dp minimum and the list keeps
  /// ~580dp, which still holds a usable grid. Below that the list would be down
  /// to a single column of products. Matches the tier the POS screen docks its
  /// cart at, so both screens split at the same window width.
  static const Breakpoint splitBreakpoint = Breakpoint.expanded;

  /// Whether the space [context] sits in is wide enough for two panes.
  ///
  /// The single source of truth for the split decision: the master wrapper and
  /// the detail route both call this, from the same breakpoint scope, so they
  /// cannot disagree about which of them is showing the detail.
  ///
  /// Must be called from `build` (or another method that creates an inherited
  /// dependency) to stay resize-live.
  static bool isSplitActive(BuildContext context) =>
      context.isAtLeast(splitBreakpoint);

  /// Dismisses the detail pane.
  ///
  /// A pop, not a `go`, because the detail and edit routes are nested: popping
  /// `/products/p1/edit` lands on `/products/p1` and popping that lands on
  /// `/products`, which is what "close" means at each depth.
  static void closeDetail(BuildContext context, String basePath) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(basePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final selectedId = selectionParser(uri);

    // Resize-live: this reads the enclosing scope's LayoutBuilder, so a window
    // drag rebuilds it. See the class doc on the pageBuilder trap.
    if (!isSplitActive(context)) {
      // No selection is published when the panes are collapsed. "Selected"
      // means "open in the pane next to you"; on a narrow window the detail
      // covers the list, so highlighting a row underneath would be a lie.
      return MasterSelectionScope(selectedId: null, child: master);
    }

    // The same geometry the POS screen gives its docked cart: the list keeps
    // the room, the panel takes a clamped share of it against the trailing
    // edge. Two panels docked in one window are then the same width, and the
    // products screen does not look like a different app from the POS screen.
    final detailWidth = ContentLayout.detailPaneWidth(context.breakpointData);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // The list pane measures itself, so its grid gains and loses columns
          // from the panel's width alone - no column ladder that has to know
          // the panel is there.
          child: ModernBreakpointScope.fromLayout(
            isPane: true,
            child: MasterSelectionScope(
              selectedId: selectedId,
              child: master,
            ),
          ),
        ),
        SizedBox(
          width: detailWidth,
          child: DecoratedBox(
            // The panel's own surface, behind whatever docks in it. Read as a
            // *floor*, not as the panel's appearance: anything opaque the pane
            // renders covers it, which is fine as long as what covers it is
            // also a surface. A detail screen wanting the panel's colour should
            // let this through rather than repaint the window's canvas over it.
            decoration: const BoxDecoration(color: AppColors.surface),
            child: DecoratedBox(
              // The edge, in *front* of the content.
              //
              // It used to be a `border` on the decoration above, which paints
              // behind the child - so the moment anything opaque docked here,
              // the rule went with it. That is what made the panel merge into
              // the list as soon as a row was selected: an empty panel showed
              // the surface and the edge, a filled one showed neither.
              //
              // Still a border on the panel rather than a VerticalDivider
              // between the two, matching the cart: the edge belongs to the
              // thing that docks. Only the paint order changed.
              position: DecorationPosition.foreground,
              decoration: const BoxDecoration(
                border: Border(
                  left:
                      BorderSide(color: AppColors.border, width: dividerWidth),
                ),
              ),
              child: Padding(
                // Keeps the panel's content beside the rule rather than under
                // it. A foreground decoration does not inset its child on its
                // own, so without this the leading pixel of every docked
                // header would sit beneath the edge.
                padding: const EdgeInsets.only(left: dividerWidth),
                child: ModernBreakpointScope.fromLayout(
                  isPane: true,
                  child: DetailPaneScope(
                    onClose: () => closeDetail(context, basePath),
                    child: selectedId == null
                        ? (placeholderBuilder?.call(context) ??
                            const SizedBox.shrink())
                        : detailBuilder(context, uri, selectedId),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The detail route's child, wrapped so it renders nothing while the master's
/// pane is already showing it.
///
/// The page it goes into must be non-opaque - always, never toggled. On a
/// narrow window the detail screen's own `Scaffold` is opaque and covers the
/// list anyway, so the only cost is the list staying painted underneath, which
/// is a small win: its scroll position survives the round trip.
///
/// Toggling `opaque` with the tier would be the tempting alternative and is a
/// trap: `Route.opaque` is read when the route is installed, so flipping it
/// after a resize does not restack anything.
class SplitDetailRoute extends StatelessWidget {
  const SplitDetailRoute({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MasterDetailScaffold.isSplitActive(context)) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

/// A page for a detail that a [MasterDetailScaffold] may already be showing.
///
/// ## Why this is not a `CustomTransitionPage`
///
/// Rendering nothing is not enough to get out of the way. Every [ModalRoute]
/// creates *two* overlay entries - the page's own scope, and a full-screen
/// [ModalBarrier] in front of everything below it. On an opaque page the
/// barrier is invisible because the page covers the same area anyway; on a
/// non-opaque one it becomes a sheet of glass over the whole content area,
/// silently eating every pointer event aimed at the master pane underneath.
///
/// That was the freeze: with a product open at desktop width, the list stopped
/// responding to clicks and only the navigation rail still worked - because the
/// rail is built by the `ShellRoute` builder, outside this Navigator's overlay,
/// and so was the only thing the barrier did not cover.
///
/// [buildModalBarrier] is the documented extension point for exactly this, so
/// the barrier stands down whenever the pane is the one showing the detail, and
/// behaves normally at every width where this page is a real page.
class SplitDetailPage<T> extends Page<T> {
  const SplitDetailPage({
    required LocalKey super.key,
    required this.child,
    required this.transitionsBuilder,
    required this.transitionDuration,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The detail screen. Wrapped in a [SplitDetailRoute], so it collapses on its
  /// own when the pane takes over.
  final Widget child;

  /// How this page animates in and out when it *is* the presentation - which is
  /// only ever below [MasterDetailScaffold.splitBreakpoint].
  final RouteTransitionsBuilder transitionsBuilder;

  final Duration transitionDuration;

  @override
  Route<T> createRoute(BuildContext context) => _SplitDetailPageRoute<T>(this);
}

class _SplitDetailPageRoute<T> extends PageRoute<T> {
  _SplitDetailPageRoute(SplitDetailPage<T> page) : super(settings: page);

  SplitDetailPage<T> get _page => settings as SplitDetailPage<T>;

  /// Never toggled with the tier: `opaque` is read when the route is installed,
  /// so flipping it after a resize restacks nothing.
  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _page.transitionDuration;

  /// Stands the barrier down while the pane is showing this detail.
  ///
  /// Read from a [Builder] rather than from the route, so the decision creates
  /// an inherited dependency on the breakpoint scope and is therefore
  /// resize-live - the same reason the panes themselves decide in `build`.
  @override
  Widget buildModalBarrier() {
    return Builder(
      builder: (context) => MasterDetailScaffold.isSplitActive(context)
          ? const SizedBox.shrink()
          : super.buildModalBarrier(),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SplitDetailRoute(child: _page.child);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _page.transitionsBuilder(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Publishes which item the detail pane is showing, so list items can render an
/// "open" state.
///
/// Null whenever the panes are collapsed - see [MasterDetailScaffold.build].
class MasterSelectionScope extends InheritedWidget {
  const MasterSelectionScope({
    super.key,
    required this.selectedId,
    required super.child,
  });

  final String? selectedId;

  /// The open item's id, or null when nothing is open beside the list.
  static String? selectedIdOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MasterSelectionScope>()
      ?.selectedId;

  @override
  bool updateShouldNotify(MasterSelectionScope oldWidget) =>
      oldWidget.selectedId != selectedId;
}

/// Tells a detail screen it is being rendered as a pane rather than as a route.
///
/// A pane owns no navigation: it has nothing to go back to and no business
/// carrying the account menu, which belongs to the window once. A screen reads
/// this to pick `ModernAppBar.pane()` over `ModernAppBar.backWithActions()` and
/// to route its dismissals through [onClose].
///
/// Extracting a chrome-less `ProductDetailView` would achieve the same thing by
/// moving ~400 lines for no functional gain; a flag and a six-line branch does
/// not. (The POS cart in RESP_06 is the opposite case - real duplication across
/// two files - and gets extracted instead.)
class DetailPaneScope extends InheritedWidget {
  const DetailPaneScope({
    super.key,
    required this.onClose,
    required super.child,
  });

  /// Dismisses the pane. Pops one level of the nested route stack.
  final VoidCallback onClose;

  static DetailPaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPaneScope>();

  /// Whether [context] is inside a detail pane.
  static bool isPaneOf(BuildContext context) => maybeOf(context) != null;

  // The identity of `onClose` changes on every rebuild of the scaffold while
  // meaning the same thing, and what dependents actually branch on is whether
  // this scope exists at all - which is a tree-shape change, not a data change,
  // and rebuilds them regardless.
  @override
  bool updateShouldNotify(DetailPaneScope oldWidget) => false;
}
