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
}
