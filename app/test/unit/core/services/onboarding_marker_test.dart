import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/services/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The predicate the router's onboarding gate turns on.
///
/// It reads auth metadata rather than a table because the redirect is
/// synchronous - see the note on [SupabaseClientProvider.onboardingCompletedAtKey].
/// That makes it a pure function of the user object, and worth pinning: get it
/// backwards and either every existing shop is marched through the wizard
/// again, or no new one ever sees it.
void main() {
  User userWith(Map<String, dynamic>? metadata) => User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: metadata,
        aud: 'authenticated',
        createdAt: DateTime(2026, 7, 31).toIso8601String(),
      );

  test('a signed-out user has not onboarded', () {
    expect(SupabaseClientProvider.isOnboardingCompleteFor(null), isFalse);
  });

  test('a fresh account has not onboarded', () {
    expect(
      SupabaseClientProvider.isOnboardingCompleteFor(
        userWith({'full_name': 'Bu Sri'}),
      ),
      isFalse,
    );
  });

  test('no metadata at all has not onboarded', () {
    expect(SupabaseClientProvider.isOnboardingCompleteFor(userWith(null)),
        isFalse);
  });

  test('the marker written by the wizard counts', () {
    expect(
      SupabaseClientProvider.isOnboardingCompleteFor(
        userWith({
          'full_name': 'Bu Sri',
          SupabaseClientProvider.onboardingCompletedAtKey:
              '2026-07-31T00:00:00Z',
        }),
      ),
      isTrue,
    );
  });

  test('the key matches what the seed writes', () {
    // `seed.sql` writes this exact string into `raw_user_meta_data`. A rename
    // here silently re-onboards every existing account.
    expect(
      SupabaseClientProvider.onboardingCompletedAtKey,
      'onboarding_completed_at',
    );
  });
}
