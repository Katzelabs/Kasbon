import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_provider.dart';

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

  /// Two accounts are the same account when they name the same person at the
  /// same address. Without this, every token refresh produced a fresh instance
  /// and rebuilt the rail for an identity that had not changed.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShellAccount && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}

/// Identity of the signed-in user, in the shape the navigation rail's footer
/// needs.
///
/// Derived from [userInfoProvider] rather than reading `Supabase.instance`
/// itself. That read is why the footer used to keep naming whoever signed in
/// first: a root-scoped `Provider` that watches nothing computes once and
/// caches forever, and signing out only unmounts the shell - it does not
/// invalidate a provider that is not `autoDispose`. The next user signed in,
/// the rail rebuilt, and the cached value was still the previous account's.
/// [userInfoProvider] watches the auth stream, so depending on it is what makes
/// this react to sign-in, sign-out and a switch between the two.
///
/// Returns null when there is no session *or* when Supabase has not been
/// initialised - a widget test pumping the shell never calls
/// `Supabase.initialize`, and a navigation rail is not worth an exception, so
/// the footer renders a generic account row instead.
///
/// Override this in tests to pin a name:
///
/// ```dart
/// shellAccountProvider.overrideWithValue(
///   const ShellAccount(name: 'Budi', email: 'budi@toko.id'),
/// )
/// ```
final shellAccountProvider = Provider<ShellAccount?>((ref) {
  final user = ref.watch(userInfoProvider);
  if (!user.isSignedIn) return null;

  return ShellAccount(name: user.name, email: user.email);
});
