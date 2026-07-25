import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/debt/presentation/screens/debt_list_screen.dart';
import '../../features/dev_tools/presentation/screens/design_system_showcase_screen.dart';
import '../../features/dev_tools/presentation/screens/dev_seed_screen.dart';
import '../../features/dev_tools/presentation/screens/dev_tools_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/pos/presentation/screens/transaction_success_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/products/presentation/screens/product_form_screen.dart';
import '../../features/products/presentation/screens/product_list_screen.dart';
import '../../features/receipt/presentation/screens/receipt_screen.dart';
import '../../features/reports/presentation/screens/product_report_screen.dart';
import '../../features/reports/presentation/screens/profit_report_screen.dart';
import '../../features/reports/presentation/screens/reports_hub_screen.dart';
import '../../features/reports/presentation/screens/sales_report_screen.dart';
import '../../features/backup/presentation/screens/backup_restore_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/app_settings_screen.dart';
import '../../features/settings/presentation/screens/receipt_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/shop_profile_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/transactions/presentation/screens/transaction_list_screen.dart';
import '../../shared/modern/modern.dart';

/// Route names for the application
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String splash = '/';
  static const String dashboard = '/dashboard';
  static const String pos = '/pos';
  static const String posSuccess = '/pos/success/:transactionId';
  static const String products = '/products';
  static const String productDetail = '/products/:id';
  static const String productAdd = '/products/add';
  static const String productEdit = '/products/:id/edit';
  static const String transactions = '/transactions';
  static const String transactionDetail = '/transactions/:id';
  static const String reports = '/reports';
  static const String reportsSales = '/reports/sales';
  static const String reportsProducts = '/reports/products';
  static const String reportsProfit = '/reports/profit';
  static const String debts = '/debts';
  static const String settings = '/settings';
  static const String settingsShopProfile = '/settings/shop-profile';
  static const String settingsReceipt = '/settings/receipt';
  static const String settingsApp = '/settings/app';
  static const String settingsAbout = '/settings/about';
  static const String settingsBackup = '/settings/backup';
  static const String dev = '/dev';
  static const String designSystem = '/dev/design-system';
  static const String devSeed = '/dev/seed';

  /// A receipt belongs to a transaction, so it is addressed as one. It used to
  /// be a top-level `/receipt/:transactionId`; nesting it under the
  /// transaction is what lets navigation use `go` (see the note on
  /// [AppRouter.router]) without stranding the screen with no way back.
  static const String receipt = '/transactions/:id/receipt';

  // Path builders for the parameterized routes above. The constants hold the
  // `:id` patterns GoRouter matches on, so they cannot be navigated to
  // directly - every call site goes through a builder instead of
  // interpolating an id into a URL string by hand.
  static String productDetailPath(String id) => '/products/$id';
  static String productEditPath(String id) => '/products/$id/edit';
  static String transactionDetailPath(String id) => '/transactions/$id';
  static String receiptPath(String transactionId) =>
      '/transactions/$transactionId/receipt';
  static String posSuccessPath(String transactionId) =>
      '/pos/success/$transactionId';
}

/// Converts Supabase auth state stream into a ChangeNotifier for GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Application router configuration using GoRouter
///
/// ## Navigate with `go`, not `push`
///
/// `context.push` does not update the reported URL: go_router keeps
/// [GoRouter.routerDelegate]'s configuration on the last `go` target and
/// tracks imperative pushes separately, so pushing `/products/:id` leaves the
/// address bar on `/products` while the detail screen is on screen.
///
/// `context.go` updates the URL, and for a route nested in this table it also
/// synthesises the parent stack - `go('/products/abc/edit')` builds
/// `/products` -> `/products/abc` -> `/products/abc/edit`, so `context.pop()`
/// and the browser Back button both still work.
///
/// The corollary is that every screen you can drill into must be *nested under
/// the screen you reach it from*, or `go` will land on it with nothing to pop
/// back to. That is why the receipt is `/transactions/:id/receipt` rather than
/// a top-level `/receipt/:id`, and why the dev screens hang off `/dev`.
///
/// One consequence to be aware of: because the back stack comes from the URL
/// hierarchy rather than from history, opening a debt from `/debts` lands on
/// `/transactions/:id` and backs out to `/transactions`, not to `/debts`.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.uri.path == AppRoutes.login ||
          state.uri.path == AppRoutes.register;

      if (!isLoggedIn && !isAuthRoute) {
        return AppRoutes.login;
      }
      if (isLoggedIn && isAuthRoute) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      // Root "/" redirect to dashboard
      GoRoute(
        path: '/',
        redirect: (_, __) => AppRoutes.dashboard,
      ),

      // Auth routes (outside shell, no bottom nav)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => _slidePage(
          state: state,
          child: const RegisterScreen(),
        ),
      ),

      // Main navigation shell (bottom nav on mobile, sidebar on tablet)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ModernAppShell(
            currentPath: state.uri.path,
            child: child,
          );
        },
        routes: [
          // Dashboard (Main screen)
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const DashboardScreen(),
            ),
          ),

          // POS Screen
          GoRoute(
            path: AppRoutes.pos,
            name: 'pos',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const PosScreen(),
            ),
          ),

          // Products with nested routes (list, detail, add, edit)
          GoRoute(
            path: AppRoutes.products,
            name: 'products',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const ProductListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                name: 'product-add',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const ProductFormScreen(),
                ),
              ),
              GoRoute(
                path: ':id',
                name: 'product-detail',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _slidePage(
                    state: state,
                    child: ProductDetailScreen(productId: id),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'product-edit',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return _slidePage(
                        state: state,
                        child: ProductFormScreen(productId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Transactions with nested detail route
          GoRoute(
            path: AppRoutes.transactions,
            name: 'transactions',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const TransactionListScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: 'transaction-detail',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _slidePage(
                    state: state,
                    child: TransactionDetailScreen(transactionId: id),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'receipt',
                    name: 'receipt',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return _slidePage(
                        state: state,
                        child: ReceiptScreen(transactionId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Reports with nested routes
          GoRoute(
            path: AppRoutes.reports,
            name: 'reports',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const ReportsHubScreen(),
            ),
            routes: [
              GoRoute(
                path: 'sales',
                name: 'reports-sales',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const SalesReportScreen(),
                ),
              ),
              GoRoute(
                path: 'products',
                name: 'reports-products',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const ProductReportScreen(),
                ),
              ),
              GoRoute(
                path: 'profit',
                name: 'reports-profit',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const ProfitReportScreen(),
                ),
              ),
            ],
          ),

          // Debts (Hutang)
          GoRoute(
            path: AppRoutes.debts,
            name: 'debts',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const DebtListScreen(),
            ),
          ),

          // Settings with nested routes
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const SettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'shop-profile',
                name: 'settings-shop-profile',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const ShopProfileScreen(),
                ),
              ),
              GoRoute(
                path: 'receipt',
                name: 'settings-receipt',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const ReceiptSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'app',
                name: 'settings-app',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const AppSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'about',
                name: 'settings-about',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const AboutScreen(),
                ),
              ),
              GoRoute(
                path: 'backup',
                name: 'settings-backup',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const BackupRestoreScreen(),
                ),
              ),
            ],
          ),

          // Dev Tools (development only)
          GoRoute(
            path: AppRoutes.dev,
            name: 'dev',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const DevToolsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'design-system',
                name: 'design-system',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const DesignSystemShowcaseScreen(),
                ),
              ),
              GoRoute(
                path: 'seed',
                name: 'dev-seed',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const DevSeedScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes (outside shell)
      GoRoute(
        path: AppRoutes.posSuccess,
        name: 'pos-success',
        pageBuilder: (context, state) {
          final transactionId = state.pathParameters['transactionId']!;
          return _slidePage(
            state: state,
            child: TransactionSuccessScreen(transactionId: transactionId),
          );
        },
      ),
    ],

    // Error handling
    errorPageBuilder: (context, state) => _fadePage(
      state: state,
      child: _ErrorScreen(error: state.error.toString()),
    ),
  );

  /// A page for a top-level destination - the shell's tabs and any screen you
  /// arrive at sideways rather than by drilling in. Switching tabs has no
  /// forward/back meaning, so a directional slide would imply a hierarchy
  /// that is not there. Crossfade only.
  static CustomTransitionPage<void> _fadePage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _RouteMotion.fadeDuration,
      reverseTransitionDuration: _RouteMotion.fadeDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// A page for a screen you drill into (detail, edit, sub-section). Slides in
  /// from the leading edge while the page it covers drifts back and dims, so
  /// depth is legible and the back gesture has an obvious inverse.
  static CustomTransitionPage<void> _slidePage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _RouteMotion.pushDuration,
      reverseTransitionDuration: _RouteMotion.pushDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _SlideFadeTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }
}

/// Motion tokens for route transitions, kept next to the theme tokens in
/// spirit: durations and curves live in one place so every route animates on
/// the same clock.
class _RouteMotion {
  _RouteMotion._();

  static const Duration pushDuration = Duration(milliseconds: 300);
  static const Duration fadeDuration = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;

  /// How far the entering page travels, as a fraction of its own width.
  static const double enterOffset = 0.30;

  /// The covered page moves a shorter distance in the opposite direction -
  /// matching the entering page's travel would read as two pages swapping
  /// places rather than one stacking on the other.
  static const double exitOffset = 0.10;

  /// The covered page dims rather than disappearing; it is still there.
  static const double exitOpacity = 0.6;
}

/// Slide-and-fade used by [AppRouter._slidePage].
///
/// Drives both the entering page (via [animation]) and the page being covered
/// (via [secondaryAnimation]) so a push and its pop are exact inverses.
class _SlideFadeTransition extends StatelessWidget {
  const _SlideFadeTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Travel follows text direction, so "forward" still moves inward from the
    // leading edge in an RTL locale.
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

    // Curves are applied with CurveTween rather than CurvedAnimation: a
    // CurvedAnimation allocated in build() would need disposing, and these are
    // rebuilt on every frame of the transition.
    final ease = CurveTween(curve: _RouteMotion.curve);

    final outgoing = SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-_RouteMotion.exitOffset * sign, 0),
      ).chain(ease).animate(secondaryAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: _RouteMotion.exitOpacity)
            .chain(ease)
            .animate(secondaryAnimation),
        child: child,
      ),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(_RouteMotion.enterOffset * sign, 0),
        end: Offset.zero,
      ).chain(ease).animate(animation),
      child: FadeTransition(
        opacity: animation.drive(ease),
        child: outgoing,
      ),
    );
  }
}

/// Error screen for handling navigation errors
class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Halaman tidak ditemukan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Kembali ke Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
