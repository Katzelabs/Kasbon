/// Application configuration for Supabase-backed KASBON POS.
///
/// Values come from an env file (see `env.example.json`):
///   flutter run --dart-define-from-file=env.json
///   flutter build apk --dart-define-from-file=env.prod.json
///
/// Individual `--dart-define=KEY=value` flags still work and override nothing —
/// use one style or the other.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _legacyAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Supabase client key: the publishable key (`sb_publishable_...`),
  /// falling back to a legacy anon key if that's all that was provided.
  static const String supabaseKey =
      _publishableKey != '' ? _publishableKey : _legacyAnonKey;

  static bool get isConfigValid =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Sentry DSN.
  ///
  /// Unlike the Supabase values above, an empty DSN is *not* an error: it means
  /// "don't report", which is what local dev, `flutter test` and CI all want.
  /// A missing DSN must therefore be a clean no-op — see
  /// `core/observability/crash_reporting.dart`. The DSN is not a secret (it
  /// ships in every client and only permits writes), but it stays out of the
  /// repo so a fork's crashes don't land in this project's inbox.
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// True in an AOT/dart2js release build. Pure Dart on purpose — this file has
  /// no Flutter import, and `kReleaseMode` would add one for a const bool that
  /// the SDK already defines.
  static const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  static const String _sentryEnvironmentOverride = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: '',
  );

  /// Which deployment an event came from, so a crash on the counter is not
  /// filed next to one from a laptop mid-refactor. Defaults by build mode, so
  /// an unset value still tells the two apart.
  ///
  /// Empty falls back rather than being passed through: an env file that lists
  /// the key with a blank value — which is how `env.example.json` documents it
  /// — *does* define it, so `defaultValue` would never apply and every build
  /// would report an empty environment.
  static const String sentryEnvironment = _sentryEnvironmentOverride != ''
      ? _sentryEnvironmentOverride
      : (_isReleaseBuild ? 'production' : 'development');

  static bool get isCrashReportingEnabled => sentryDsn.isNotEmpty;
}
