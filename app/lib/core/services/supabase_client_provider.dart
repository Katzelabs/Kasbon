import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides access to the Supabase client and current user info.
class SupabaseClientProvider {
  /// Key under which the onboarding marker lives in the user's auth metadata.
  ///
  /// It lives there, rather than in a `user_profiles` column, because the
  /// router's redirect is synchronous: metadata is already in memory at first
  /// frame, while a table read is a round trip that would paint the dashboard
  /// and then yank a half-onboarded user away from it on every cold start.
  static const String onboardingCompletedAtKey = 'onboarding_completed_at';

  SupabaseClient get client => Supabase.instance.client;

  /// Current authenticated user ID, or null if not logged in.
  String? get currentUserId => client.auth.currentUser?.id;

  /// Whether the current user has finished the onboarding wizard.
  ///
  /// False when signed out, so callers must check for a session first if they
  /// care about the difference between "not onboarded" and "nobody here".
  bool get isOnboardingComplete =>
      isOnboardingCompleteFor(client.auth.currentUser);

  /// [isOnboardingComplete] for an arbitrary user - for callers holding a
  /// [User] directly, such as the router's redirect.
  static bool isOnboardingCompleteFor(User? user) =>
      user?.userMetadata?[onboardingCompletedAtKey] != null;

  /// Current authenticated user ID. Throws if not logged in.
  String get requireUserId {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('User is not authenticated');
    }
    return uid;
  }

  /// Stream of auth state changes.
  Stream<AuthState> get onAuthStateChange =>
      client.auth.onAuthStateChange;
}
