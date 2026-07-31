import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Who is signed in, in the shape the app bar and the settings header need.
class UserInfo {
  const UserInfo({
    required this.name,
    this.email,
    this.avatarUrl,
  });

  /// Display name. Falls back to the email's local part, then to a generic
  /// label, so this is always safe to render.
  final String name;

  /// The signed-in address. Null only when nobody is signed in.
  final String? email;

  final String? avatarUrl;

  /// Whether a session is backing this, as opposed to the signed-out default.
  bool get isSignedIn => email != null;

  /// Nobody signed in - what the app bar shows on the auth screens.
  static const UserInfo signedOut = UserInfo(name: 'Pengguna');

  /// One or two letters for the avatar.
  ///
  /// Two initials only when the name really is two words: an email-derived name
  /// like `budi.santoso` is one token as far as the user is concerned, and
  /// splitting it produced "BS" for someone who never gave a surname.
  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  UserInfo copyWith({
    String? name,
    String? email,
    String? avatarUrl,
  }) {
    return UserInfo(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Value equality, so a token refresh - which re-emits the same identity
  /// through [authStateProvider] - does not count as a change and does not
  /// rebuild every app bar and the navigation rail's footer.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInfo &&
          other.name == name &&
          other.email == email &&
          other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(name, email, avatarUrl);
}

/// The signed-in user, derived from the Supabase session.
///
/// This was a `StateProvider` holding a hardcoded `UserInfo(name: 'Pengguna')`
/// with a comment promising it would one day come from the backend. Nothing
/// ever wrote to it, so every avatar in every app bar rendered "P" no matter
/// who was signed in.
///
/// Watching [authStateProvider] rather than reading the client once is what
/// makes it react: signing in, signing out and a token refresh all push through
/// that stream, and a `Provider` that only read `currentUser` at creation would
/// keep showing the previous user until something else invalidated it.
/// Whether Supabase has been initialised.
///
/// `Supabase.instance` throws rather than returning null when `initialize` has
/// not run. In the app that never happens - `main` awaits it before `runApp` -
/// but a widget test pumps a screen with no Supabase at all, and the app bar on
/// nearly every screen reads this provider. Letting the throw escape replaced
/// the account menu with a full-size error widget inside the toolbar's `Row`,
/// which is how one uninitialised singleton turned into 178 failing layout
/// tests overflowing by 98,900 pixels.
User? _currentUserOrNull() {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}

final userInfoProvider = Provider<UserInfo>((ref) {
  // Same reasoning as above: watching the stream is what makes this react to
  // sign-in and sign-out, but creating it touches the same singleton.
  try {
    ref.watch(authStateProvider);
  } catch (_) {
    return UserInfo.signedOut;
  }

  final user = _currentUserOrNull();
  if (user == null) return UserInfo.signedOut;

  final email = user.email;
  final metadataName = (user.userMetadata?['full_name'] as String?)?.trim();

  return UserInfo(
    // `full_name` is what the signup trigger copies into `user_profiles`, so
    // it is the same name the rest of the app knows the user by. Without it,
    // the local part of the address beats a generic placeholder.
    name: (metadataName != null && metadataName.isNotEmpty)
        ? metadataName
        : (email?.split('@').first ?? 'Pengguna'),
    email: email,
    avatarUrl: user.userMetadata?['avatar_url'] as String?,
  );
});

/// Which account is signed in, as an id - null when none is.
///
/// The signal the app resets its per-account state on. It is deliberately the
/// *id* rather than [userInfoProvider]: a name change is still the same
/// account and must not throw away a cart, while `null -> uid` and
/// `uid -> other uid` are exactly the transitions that must. A token refresh
/// re-emits the same string, and Riverpod suppresses a notification for an
/// unchanged value, so listeners hear only real account changes.
final currentUserIdProvider = Provider<String?>((ref) {
  // Same guard as [userInfoProvider]: creating the stream provider touches
  // `Supabase.instance`, which throws before `initialize`.
  try {
    ref.watch(authStateProvider);
  } catch (_) {
    return null;
  }

  return _currentUserOrNull()?.id;
});
