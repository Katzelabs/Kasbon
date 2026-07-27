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
import 'config/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/platform/app_platform.dart';

void main() async {
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

  // Initialize Supabase
  assert(AppConfig.isConfigValid,
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be provided, e.g. '
      'flutter run --dart-define-from-file=env.json');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseKey,
  );

  // Configure dependency injection
  await configureDependencies();

  // Run the app
  runApp(
    const ProviderScope(
      child: KasbonApp(),
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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
