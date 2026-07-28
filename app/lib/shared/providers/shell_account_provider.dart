import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The bare identity the app shell needs to draw an account row.
///
/// Deliberately not `UserProfile`: that entity comes from a repository call
/// behind GetIt, and shell chrome must not be able to fail, wait, or pull the
/// DI graph into a widget test just to label a row in the navigation rail.
class ShellAccount {
  /// Display name - the profile's full name, falling back to the email.
  final String name;

  /// Sign-in email, when the session carries one.
  final String? email;

  const ShellAccount({required this.name, this.email});

  /// One or two letters for [ModernAvatar.initials].
  String get initials {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words[1].substring(0, 1))
        .toUpperCase();
  }
}

/// Identity of the signed-in user, read straight from the Supabase session.
///
/// Returns null when there is no session *or* when Supabase has not been
/// initialised. The second case is the one that matters: `Supabase.instance`
/// throws before `Supabase.initialize`, and a widget test pumping the shell
/// never calls it. A navigation rail is not worth an exception, so the footer
/// renders a generic account row instead.
///
/// Override this in tests to pin a name:
///
/// ```dart
/// shellAccountProvider.overrideWithValue(
///   const ShellAccount(name: 'Budi', email: 'budi@toko.id'),
/// )
/// ```
final shellAccountProvider = Provider<ShellAccount?>((ref) {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final fullName = (user.userMetadata?['full_name'] as String?)?.trim();
    final email = user.email;

    return ShellAccount(
      name: (fullName != null && fullName.isNotEmpty)
          ? fullName
          : (email ?? 'Akun'),
      email: email,
    );
  } catch (_) {
    return null;
  }
});
