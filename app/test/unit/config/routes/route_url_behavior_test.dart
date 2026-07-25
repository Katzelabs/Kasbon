import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pins the go_router behaviour the app's navigation depends on.
///
/// The real [AppRouter.router] cannot be pumped here - it is a lazily
/// initialised static that reaches for `Supabase.instance` - so this rebuilds a
/// route table with the same shape: a ShellRoute holding list screens, with
/// detail/edit nested underneath.
///
/// What it locks in is the reason every call site uses `go` and not `push`:
/// `push` leaves the reported URL behind, which is why Chrome's address bar
/// stayed on `/products` while a product detail screen was on screen. If a
/// go_router upgrade changes any of this, these fail rather than the address
/// bar silently going stale again.
void main() {
  GoRouter buildRouter() {
    return GoRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'shell'),
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (c, s) => const MaterialPage(child: Text('dash')),
            ),
            GoRoute(
              path: '/products',
              pageBuilder: (c, s) => const MaterialPage(child: Text('list')),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (c, s) => MaterialPage(
                    child: Text('detail ${s.pathParameters['id']}'),
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      pageBuilder: (c, s) => MaterialPage(
                        child: Text('edit ${s.pathParameters['id']}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Uri reportedUrl(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri;

  testWidgets('push shows the screen but does NOT update the URL',
      (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/products');
    await tester.pumpAndSettle();

    router.push('/products/abc');
    await tester.pumpAndSettle();

    // The screen changed...
    expect(find.text('detail abc'), findsOneWidget);
    // ...but the address bar did not. This is the bug.
    expect(reportedUrl(router).toString(), '/products');
  });

  testWidgets('go updates the URL for a dynamic path param', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/products/abc');
    await tester.pumpAndSettle();

    expect(find.text('detail abc'), findsOneWidget);
    expect(reportedUrl(router).toString(), '/products/abc');

    router.go('/products/abc/edit');
    await tester.pumpAndSettle();

    expect(find.text('edit abc'), findsOneWidget);
    expect(reportedUrl(router).toString(), '/products/abc/edit');
  });

  testWidgets('go into a nested route still leaves a poppable back stack',
      (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Land directly on the deepest route, as a deep link or a refresh would.
    router.go('/products/abc/edit');
    await tester.pumpAndSettle();

    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('detail abc'), findsOneWidget);
    expect(reportedUrl(router).toString(), '/products/abc');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(reportedUrl(router).toString(), '/products');
  });

  testWidgets('go to a NON-nested route strands it with nothing to pop',
      (tester) async {
    // This is why the receipt moved under /transactions/:id and the dev
    // screens moved under /dev - a top-level route reached with go has no
    // parent to synthesise, so its back button would have had nothing to do.
    final router = GoRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
      initialLocation: '/transactions',
      routes: [
        GoRoute(
          path: '/transactions',
          pageBuilder: (c, s) => const MaterialPage(child: Text('txns')),
        ),
        GoRoute(
          path: '/receipt/:id',
          pageBuilder: (c, s) => const MaterialPage(child: Text('receipt')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/receipt/t1');
    await tester.pumpAndSettle();

    expect(find.text('receipt'), findsOneWidget);
    expect(reportedUrl(router).toString(), '/receipt/t1');
    expect(router.canPop(), isFalse);
  });
}
