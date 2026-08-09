import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/di/injection.dart';
import 'config/routes/app_router.dart';
import 'config/routes/url_strategy.dart';
import 'config/session/session_reset.dart';
import 'config/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/observability/crash_reporting.dart';
import 'core/platform/app_platform.dart';
import 'core/services/secure_session_storage.dart';
import 'core/platform/app_scroll_behavior.dart';
import 'core/responsive/modern_breakpoint_scope.dart';

void main() async {
  // Everything runs inside this, including the setup below, so a failure while
  // wiring up Supabase or DI is reported rather than lost — startup is exactly
  // where a misconfigured release build breaks, and the phase nobody is
  // watching a console for. A no-op when no DSN is configured.
  await runWithCrashReporting(_startApp);
}

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Serve real paths instead of go_router's default hash URLs. No-op off web.
  configureUrlStrategy();

  // The browser owns rotation and the status bar, so these are wasted calls
  // there - setPreferredOrientations in particular is not merely ignored but
  // unsupported on web.
  if (AppPlatform.usesSystemOverlayStyle) {
    // Allow all orientations for tablet support
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Initialize Indonesian locale data for date formatting
  await initializeDateFormatting('id_ID', null);

  // Initialize Supabase.
  //
  // A throw rather than an assert, because asserts are compiled out of release
  // builds and this is exactly the check that matters there: `flutter build`
  // without --dart-define-from-file produces empty strings, not an error, so
  // the app would ship, initialise against "" and fail later at the first query
  // with something that reads like a network fault. Failing at startup names
  // the actual cause.
  if (!AppConfig.isConfigValid) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be provided, e.g. '
      'flutter run --dart-define-from-file=env.json '
      '(or --dart-define-from-file=env.prod.json for a release build).',
    );
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseKey,
    // The refresh token goes in the platform keystore rather than a plaintext
    // preferences file. See core/services/secure_session_storage.dart.
    authOptions: FlutterAuthClientOptions(
      localStorage: buildSessionStorage(),
    ),
  );

  // Configure dependency injection
  await configureDependencies();

  // Run the app
  runApp(
    const ProviderScope(
      // Above the router deliberately: an account change has to be able to
      // clear the previous account's state no matter which screen triggered it.
      child: SessionGate(
        child: KasbonApp(),
      ),
    ),
  );
}

/// Root application widget
class KasbonApp extends StatelessWidget {
  const KasbonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,

      // Localization
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Indonesian
        Locale('en', 'US'), // English fallback
      ],
      locale: const Locale('id', 'ID'),

      // Mouse and trackpad drag-scrolling, desktop scrollbars, and physics
      // that stop bouncing off a phone. Set here so every scroll view in the
      // app inherits it rather than each one specifying its own physics.
      scrollBehavior: const AppScrollBehavior(),

      // Router
      routerConfig: AppRouter.router,

      // Builder for global configurations
      builder: (context, child) {
        return MediaQuery(
          // Prevent text scaling from affecting layout too much
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2),
            ),
          ),
          // Root breakpoint scope. Measures the whole window, and being
          // outermost it also establishes windowBreakpoint for every scope
          // nested inside it. Its real job is to guarantee that
          // `context.breakpoint` is never a MediaQuery fallback, including on
          // the routes that sit outside the app shell.
          child: ModernBreakpointScope.fromLayout(
            inheritWindow: false,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
