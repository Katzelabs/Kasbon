import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasbon_pos/config/routes/app_router.dart';
import 'package:kasbon_pos/config/theme/app_colors.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';

import '../../../helpers/responsive_helpers.dart';

/// Exercises the split mechanism itself.
///
/// [AppRouter.router] cannot be pumped - it is a lazily initialised static that
/// reaches for `Supabase.instance` - so this builds a route table with the same
/// shape and the same two moving parts: the list wrapped in a
/// [MasterDetailScaffold], the detail behind a non-opaque page whose child goes
/// through [SplitDetailRoute].
void main() {
  /// Distinct markers so a finder can tell which half rendered what.
  const masterMarker = 'MASTER';
  const headerMarker = 'HEADER';
  String paneDetail(String id) => 'PANE-$id';
  String routeDetail(String id) => 'ROUTE-$id';
  const placeholder = 'PLACEHOLDER';

  /// Counts taps that actually reached the master, so a test can tell "the
  /// master is on screen" from "the master is still usable".
  var masterTaps = 0;

  /// What each side measured itself at. Read from inside the pane's own
  /// breakpoint scope, which is the width the screens in it actually lay out
  /// for - a widget's own rect would only report how big its content is.
  double? masterWidth;
  double? detailWidth;

  setUp(() {
    masterTaps = 0;
    masterWidth = null;
    detailWidth = null;
  });

  GoRouter buildRouter() {
    return GoRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
      initialLocation: '/products',
      routes: [
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'shell'),
          // Mirrors ModernAppShell: the scope both halves read sits above the
          // inner navigator, so a resize reaches every page in it.
          builder: (context, state, child) => Scaffold(
            body: ModernBreakpointScope.fromLayout(child: child),
          ),
          routes: [
            GoRoute(
              path: '/products',
              // Mirrors ProductListScreen: one Scaffold, one header spanning
              // the whole content area, the split inside the body.
              pageBuilder: (context, state) => MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text(headerMarker)),
                  body: MasterDetailScaffold(
                    basePath: '/products',
                    selectionParser: AppRoutes.selectedProductId,
                    detailBuilder: (context, uri, id) => Builder(
                      builder: (context) {
                        detailWidth = context.availableWidth;
                        return Text(paneDetail(id));
                      },
                    ),
                    placeholderBuilder: (context) => const Text(placeholder),
                    master: Material(
                      child: Builder(
                        builder: (context) {
                          masterWidth = context.availableWidth;
                          return TextButton(
                            onPressed: () => masterTaps++,
                            child: const Text(masterMarker),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return SplitDetailPage<void>(
                      key: state.pageKey,
                      transitionDuration: Duration.zero,
                      transitionsBuilder: (_, __, ___, child) => child,
                      // An opaque surface, like the real detail screen's
                      // Scaffold: on a narrow window it is what covers the
                      // list a non-opaque page leaves painted underneath.
                      child: Material(child: Text(routeDetail(id))),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<GoRouter> pumpAt(WidgetTester tester, double width) async {
    setViewWidth(tester, width);
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  group('deep link', () {
    testWidgets('at compact, the detail is a full page over the list',
        (tester) async {
      final router = await pumpAt(tester, ResponsiveWidths.compact);

      router.go('/products/p1');
      await tester.pumpAndSettle();

      expect(find.text(routeDetail('p1')), findsOneWidget);
      expect(find.text(paneDetail('p1')), findsNothing);
      // The list is still mounted underneath - that is the point of the
      // non-opaque page - but the detail's own surface covers it.
      expect(find.text(masterMarker), findsOneWidget);
    });

    testWidgets(
        'at large, the detail renders in the pane and the route empties',
        (tester) async {
      final router = await pumpAt(tester, ResponsiveWidths.large);

      router.go('/products/p1');
      await tester.pumpAndSettle();

      expect(find.text(paneDetail('p1')), findsOneWidget);
      expect(find.text(routeDetail('p1')), findsNothing);
      expect(find.text(masterMarker), findsOneWidget);
    });

    testWidgets('the pane shows a placeholder with nothing selected',
        (tester) async {
      await pumpAt(tester, ResponsiveWidths.large);

      expect(find.text(placeholder), findsOneWidget);
      expect(find.text(masterMarker), findsOneWidget);
    });
  });

  // The trap this guards: a route's pageBuilder runs only when go_router
  // rebuilds the route table, which a window resize does not do. Deciding the
  // split there leaves the detail permanently blank after a drag inward.
  testWidgets('resizing 1400 to 700 with a detail open keeps it visible',
      (tester) async {
    final router = await pumpAt(tester, 1400);

    router.go('/products/p1');
    await tester.pumpAndSettle();
    expect(find.text(paneDetail('p1')), findsOneWidget);

    setViewWidth(tester, 700);
    await tester.pumpAndSettle();

    // The pane is gone, so the route must have taken the detail back.
    expect(find.text(paneDetail('p1')), findsNothing);
    expect(find.text(routeDetail('p1')), findsOneWidget);
  });

  testWidgets('resizing 700 to 1400 hands the detail back to the pane',
      (tester) async {
    final router = await pumpAt(tester, 700);

    router.go('/products/p1');
    await tester.pumpAndSettle();
    expect(find.text(routeDetail('p1')), findsOneWidget);

    setViewWidth(tester, 1400);
    await tester.pumpAndSettle();

    expect(find.text(routeDetail('p1')), findsNothing);
    expect(find.text(paneDetail('p1')), findsOneWidget);
  });

  group('back', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets('pops the detail at ${ResponsiveWidths.label(width)}',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go('/products/p1');
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue);

        router.pop();
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/products',
        );
        expect(find.text(paneDetail('p1')), findsNothing);
        expect(find.text(routeDetail('p1')), findsNothing);
        expect(find.text(masterMarker), findsOneWidget);
      });
    }
  });

  // The panel docks exactly where the POS cart does, off the same rule in
  // ContentLayout. Two panels docked in one window at different widths is what
  // makes an app look like two apps.
  group('geometry', () {
    for (final width in [ResponsiveWidths.expanded, ResponsiveWidths.large]) {
      testWidgets(
          'docks trailing at the cart width, ${ResponsiveWidths.label(width)}',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go('/products/p1');
        await tester.pumpAndSettle();

        final expected = ContentLayout.detailPaneWidth(
          BreakpointData(
            breakpoint: AppBreakpoints.fromWidth(width),
            width: width,
            height: 1200,
            windowBreakpoint: AppBreakpoints.fromWidth(width),
          ),
        );

        // The panel takes the cart's share; the border it carries costs the
        // pane inside it a pixel.
        expect(detailWidth, closeTo(expected, 1));
        // ...and the list keeps everything else, rather than the other way
        // round as a conventional master/detail would have it.
        expect(masterWidth, closeTo(width - expected, 1));
        expect(masterWidth, greaterThan(detailWidth!));

        // Trailing edge.
        expect(
          tester.getRect(find.text(paneDetail('p1'))).left,
          greaterThan(tester.getRect(find.text(masterMarker)).left),
        );
      });
    }

    // The regression: the edge was a `border` on the decoration that painted
    // the panel's surface, and a background decoration paints *behind* its
    // child. Anything opaque docked in the panel - a detail screen's Scaffold,
    // a ColoredBox - therefore took the rule with it, so an empty panel showed
    // a separator and a filled one showed none.
    group('the edge between the panes', () {
      Finder paneEdge() => find.descendant(
            of: find.byType(MasterDetailScaffold),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.position == DecorationPosition.foreground,
            ),
          );

      testWidgets('is painted over the panel, not behind it', (tester) async {
        final router = await pumpAt(tester, ResponsiveWidths.large);

        router.go('/products/p1');
        await tester.pumpAndSettle();

        expect(paneEdge(), findsOneWidget);

        final decoration =
            tester.widget<DecoratedBox>(paneEdge()).decoration as BoxDecoration;
        expect(
          decoration.border,
          const Border(
            left: BorderSide(
              color: AppColors.border,
              width: MasterDetailScaffold.dividerWidth,
            ),
          ),
        );
      });

      testWidgets('is there with nothing selected too', (tester) async {
        await pumpAt(tester, ResponsiveWidths.large);

        expect(paneEdge(), findsOneWidget);
      });

      testWidgets('leaves the panel content beside it, not under it',
          (tester) async {
        final router = await pumpAt(tester, ResponsiveWidths.large);

        router.go('/products/p1');
        await tester.pumpAndSettle();

        // A foreground decoration does not inset its own child, so the panel
        // has to pay for the rule out of its content width.
        final expected = ContentLayout.detailPaneWidth(
          BreakpointData(
            breakpoint: AppBreakpoints.fromWidth(ResponsiveWidths.large),
            width: ResponsiveWidths.large,
            height: 1200,
            windowBreakpoint: AppBreakpoints.fromWidth(ResponsiveWidths.large),
          ),
        );

        expect(detailWidth, expected - MasterDetailScaffold.dividerWidth);
        expect(
          tester.getRect(find.text(paneDetail('p1'))).left,
          greaterThanOrEqualTo(
            tester.getRect(paneEdge()).left + MasterDetailScaffold.dividerWidth,
          ),
        );
      });
    });

    testWidgets('the screen header spans both panes', (tester) async {
      // The split lives inside the screen's body, the way the POS screen docks
      // its cart. Wrapping the whole screen instead would put the header in the
      // left pane, stopping short of the panel.
      final router = await pumpAt(tester, ResponsiveWidths.large);

      router.go('/products/p1');
      await tester.pumpAndSettle();

      final header = tester.getRect(find.byType(AppBar));
      final pane = tester.getRect(find.text(paneDetail('p1')));

      expect(header.width, ResponsiveWidths.large);
      expect(header.right, greaterThan(pane.left));
      expect(header.bottom, lessThanOrEqualTo(pane.top));
    });

    testWidgets('the list stays above the compact tier at large',
        (tester) async {
      // The narrow-pane affordances - forced grid, compact filter bar - are
      // gated on the list actually being compact. It is not, at this width.
      final router = await pumpAt(tester, ResponsiveWidths.large);
      router.go('/products/p1');
      await tester.pumpAndSettle();

      expect(masterWidth, greaterThan(AppBreakpoints.compactMax));
    });
  });

  // The freeze: a non-opaque page still installs a full-screen ModalBarrier,
  // which swallowed every click aimed at the list beside the pane. Only the
  // navigation rail stayed usable, because it is built outside this Navigator.
  testWidgets('the master stays interactive while the pane shows a detail',
      (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.large);

    await tester.tap(find.text(masterMarker));
    await tester.pumpAndSettle();
    expect(masterTaps, 1, reason: 'baseline, with no detail open');

    router.go('/products/p1');
    await tester.pumpAndSettle();
    expect(find.text(paneDetail('p1')), findsOneWidget);

    await tester.tap(find.text(masterMarker), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(masterTaps, 2,
        reason: 'the barrier must stand down beside the pane');
  });

  testWidgets('the barrier still blocks the list underneath at compact',
      (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.compact);

    router.go('/products/p1');
    await tester.pumpAndSettle();

    // The list is mounted under the non-opaque page, so a finder still sees
    // it. Nothing may reach it: at this width the detail is the screen.
    await tester.tap(find.text(masterMarker), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(masterTaps, 0);
  });

  testWidgets('selecting another product swaps what the pane shows',
      (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.large);

    router.go('/products/p1');
    await tester.pumpAndSettle();
    expect(find.text(paneDetail('p1')), findsOneWidget);

    router.go('/products/p2');
    await tester.pumpAndSettle();

    expect(find.text(paneDetail('p1')), findsNothing);
    expect(find.text(paneDetail('p2')), findsOneWidget);
  });

  group('AppRoutes.selectedProductId', () {
    test('reads the id out of the detail and edit locations', () {
      expect(AppRoutes.selectedProductId(Uri.parse('/products/p1')), 'p1');
      expect(AppRoutes.selectedProductId(Uri.parse('/products/p1/edit')), 'p1');
    });

    test('finds nothing to select on the list, add, or another feature', () {
      expect(AppRoutes.selectedProductId(Uri.parse('/products')), isNull);
      // `add` is a sibling route with no id. Reading it as one would send the
      // pane looking for a product called "add".
      expect(AppRoutes.selectedProductId(Uri.parse('/products/add')), isNull);
      expect(
          AppRoutes.selectedProductId(Uri.parse('/transactions/t1')), isNull);
    });
  });
}
