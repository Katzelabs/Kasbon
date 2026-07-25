import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides access to the Supabase client and current user info.
class SupabaseClientProvider {
  SupabaseClient get client => Supabase.instance.client;

  /// Current authenticated user ID, or null if not logged in.
  String? get currentUserId => client.auth.currentUser?.id;

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
