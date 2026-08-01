import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/platform/app_platform.dart';
import '../../core/utils/responsive_utils.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../core/services/supabase_client_provider.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/debt/presentation/screens/debt_list_screen.dart';
import '../../features/dev_tools/presentation/screens/design_system_showcase_screen.dart';
import '../../features/dev_tools/presentation/screens/dev_seed_screen.dart';
import '../../features/dev_tools/presentation/screens/dev_tools_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/products/presentation/screens/product_form_screen.dart';
import '../../features/products/presentation/screens/product_list_screen.dart';
import '../../features/receipt/presentation/screens/receipt_screen.dart';
import '../../features/reports/presentation/screens/analytics_report_screen.dart';
import '../../features/reports/presentation/screens/customer_report_screen.dart';
import '../../features/reports/presentation/screens/inventory_movement_screen.dart';
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
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String onboarding = '/onboarding';
  static const String splash = '/';
  static const String dashboard = '/dashboard';
  static const String pos = '/pos';
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
  static const String reportsAnalytics = '/reports/analytics';
  static const String reportsCustomers = '/reports/customers';
  static const String reportsInventory = '/reports/inventory';
  static const String debts = '/debts';

  /// A debt's detail. The same record `/transactions/:id` addresses, reached
  /// from the other list.
  ///
  /// Debt used to tap straight through to `/transactions/:id`, which is a
  /// *different branch*: `go` synthesised `/transactions` as the parent, so
  /// opening a debt and pressing back landed on the transaction history, and
  /// `/debts` had no detail of its own to dock in a pane. One route fixes both.
  ///
  /// A `/debts?tx=` query param was the cheaper-looking alternative and was
  /// rejected for the same reason the receipt is nested: a location that is not
  /// a child route synthesises no parent stack, so the narrow-screen back
  /// button would have had nothing to pop.
  static const String debtDetail = '/debts/:id';
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
  // The OTP screens carry their email in the query string rather than in
  // notifier state, so that a hard refresh on web - where these have real URLs
  // - does not strand the user on a form that no longer knows whose code it is
  // collecting.
  static String verifyEmailPath(String email) =>
      '$verifyEmail?email=${Uri.encodeQueryComponent(email)}';
  static String resetPasswordPath(String email) =>
      '$resetPassword?email=${Uri.encodeQueryComponent(email)}';

  static String productDetailPath(String id) => '/products/$id';
  static String productEditPath(String id) => '/products/$id/edit';
  static String transactionDetailPath(String id) => '/transactions/$id';
  static String debtDetailPath(String id) => '/debts/$id';
  static String receiptPath(String transactionId) =>
      '/transactions/$transactionId/receipt';

  // Selection parsers for the split views.
  //
  // These live here rather than in the split view because each is a statement
  // about the shape of a route family, and belongs next to the patterns it
  // decodes.

  /// The product id a location addresses, or null if it addresses none.
  ///
  /// Given the *full* URI, so it covers `/products/:id` and
  /// `/products/:id/edit` alike. `/products/add` is deliberately excluded: it
  /// is a sibling route with no id, not a detail of anything, and reading
  /// `add` as a product id would send the pane looking for a product by that
  /// name.
  static String? selectedProductId(Uri uri) =>
      _selectedIdUnder(uri, 'products', notIds: const {'add'});

  /// The transaction id a location addresses, or null if it addresses none.
  ///
  /// `/transactions/:id/receipt` still resolves to `:id`: the receipt is a
  /// full-screen route that covers the split entirely, and when it is dismissed
  /// the pane should still be showing the transaction it was printed from.
  static String? selectedTransactionId(Uri uri) =>
      _selectedIdUnder(uri, 'transactions');

  /// The debt id a location addresses, or null if it addresses none.
  ///
  /// Only `/debts/:id` — a debt's receipt is addressed as the transaction's,
  /// under [receipt], because there is one receipt per transaction and not one
  /// per list you reached it from.
  static String? selectedDebtId(Uri uri) => _selectedIdUnder(uri, 'debts');

  /// The id in the second segment of a `/feature/:id/...` location.
  ///
  /// [notIds] names sibling routes that occupy the id's position without being
  /// one — `/products/add`.
  static String? _selectedIdUnder(
    Uri uri,
    String feature, {
    Set<String> notIds = const {},
  }) {
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments.first != feature) return null;
    final id = segments[1];
    return notIds.contains(id) ? null : id;
  }
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
/// The same rule is why a record reachable from two lists needs a route under
/// each: because the back stack comes from the URL hierarchy rather than from
/// history, `/debts` sending you to `/transactions/:id` backed out to
/// `/transactions`. Hence [AppRoutes.debtDetail] alongside
/// [AppRoutes.transactionDetail], both rendering the same screen.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  /// Routes reachable without a session.
  ///
  /// Every one of these is also a route a *signed-in* user has no business on,
  /// which is why one set drives both halves of the redirect. Adding a screen
  /// to the auth flow without adding it here bounces the user to `/login` the
  /// moment they arrive - and sign-up no longer returns a session, so the
  /// verification screen is reached with nothing to authenticate with.
  ///
  /// `/onboarding` deliberately does **not** belong here: it needs a session.
  static const Set<String> _publicAuthRoutes = {
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.verifyEmail,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
  };

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
      final isAuthRoute = _publicAuthRoutes.contains(state.uri.path);

      if (!isLoggedIn && !isAuthRoute) {
        return AppRoutes.login;
      }
      if (isLoggedIn && isAuthRoute) {
        return AppRoutes.dashboard;
      }

      // A signed-in account with no `shop_settings` row has no shop name, no
      // categories and no products - every screen past this point renders as
      // broken. The wizard is the only thing that creates that row, so it
      // holds the door until it has.
      //
      // The marker is read from auth metadata rather than the database on
      // purpose: this callback is synchronous, and a table read here would
      // paint the dashboard and then yank the user away from it on every cold
      // start. See `SupabaseClientProvider.onboardingCompletedAtKey`.
      if (isLoggedIn &&
          state.uri.path != AppRoutes.onboarding &&
          !SupabaseClientProvider.isOnboardingCompleteFor(
            Supabase.instance.client.auth.currentUser,
          )) {
        return AppRoutes.onboarding;
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
      GoRoute(
        path: AppRoutes.verifyEmail,
        name: 'verifyEmail',
        pageBuilder: (context, state) => _slidePage(
          state: state,
          child: VerifyEmailScreen(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) => _slidePage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        pageBuilder: (context, state) => _slidePage(
          state: state,
          child: ResetPasswordScreen(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),

      // Onboarding: signed in, but outside the shell - a wizard with a bottom
      // nav bar under it is a wizard the user can walk out of halfway.
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const OnboardingScreen(),
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
          //
          // The list screen splits its own body into a list and a docked detail
          // panel when there is room; the detail's route then collapses to
          // nothing. The nesting here is untouched - see the notes on
          // MasterDetailScaffold for why a per-feature ShellRoute was rejected.
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
                  return _splitAwarePage(
                    state: state,
                    child: ProductDetailScreen(productId: id),
                  );
                },
                routes: [
                  // Editing is a screen, not a pane - at every width, and the
                  // same screen `/products/add` opens.
                  //
                  // It used to dock in the list's detail panel, which put a
                  // seven-card form into the narrowest column on the page while
                  // the products it was not about kept the wide half. A form is
                  // a task you finish and leave, so it gets the window; the
                  // panel behind it is what you land back on.
                  GoRoute(
                    path: 'edit',
                    name: 'product-edit',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return _slidePage(
                        state: state,
                        // A mounted form must not keep editing the record it
                        // was opened on. The key rebuilds the State when the
                        // selection changes; the form also re-populates from
                        // the id itself, so neither alone has to be trusted.
                        child: ProductFormScreen(
                          key: ValueKey('form-$id'),
                          productId: id,
                        ),
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
                  return _splitAwarePage(
                    state: state,
                    child: TransactionDetailScreen(transactionId: id),
                  );
                },
                routes: [
                  // A screen at every tier, deliberately. The receipt is a
                  // print preview already clamped to 400px, so a 900dp pane
                  // would show the same paper strip with more grey around it,
                  // and nesting a second split-aware page under the first buys
                  // that nothing.
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
              GoRoute(
                path: 'analytics',
                name: 'reports-analytics',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const AnalyticsReportScreen(),
                ),
              ),
              GoRoute(
                path: 'customers',
                name: 'reports-customers',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const CustomerReportScreen(),
                ),
              ),
              GoRoute(
                path: 'inventory',
                name: 'reports-inventory',
                pageBuilder: (context, state) => _slidePage(
                  state: state,
                  child: const InventoryMovementScreen(),
                ),
              ),
            ],
          ),

          // Debts (Hutang) with nested detail route
          GoRoute(
            path: AppRoutes.debts,
            name: 'debts',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const DebtListScreen(),
            ),
            routes: [
              // The same screen `/transactions/:id` renders, told which list it
              // belongs to. Two routes onto one record is the point: the branch
              // you opened it from is the branch back returns you to.
              GoRoute(
                path: ':id',
                name: 'debt-detail',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _splitAwarePage(
                    state: state,
                    child: TransactionDetailScreen(
                      transactionId: id,
                      basePath: AppRoutes.debts,
                    ),
                  );
                },
              ),
            ],
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

          // Dev Tools. Registered only in a debug build - in release these
          // routes do not exist, so /dev/seed falls through to the error page
          // like any other unknown path. See AppPlatform.exposesDevTools.
          if (AppPlatform.exposesDevTools)
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

  /// [_slidePage] for a detail that a [MasterDetailScaffold] may already be
  /// showing in a pane.
  ///
  /// A [SplitDetailPage] rather than a [CustomTransitionPage]: a non-opaque
  /// page still installs a full-screen modal barrier over everything below it,
  /// which froze the master pane. See [SplitDetailPage] for the whole story.
  static SplitDetailPage<void> _splitAwarePage({
    required GoRouterState state,
    required Widget child,
  }) {
    return SplitDetailPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _RouteMotion.pushDuration,
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
