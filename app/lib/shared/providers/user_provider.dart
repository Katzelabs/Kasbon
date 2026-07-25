import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data class representing user information for app bar display
class UserInfo {
  const UserInfo({
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  final String name;
  final String role;
  final String? avatarUrl;

  /// Get initials from user name
  String get initials {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  UserInfo copyWith({
    String? name,
    String? role,
    String? avatarUrl,
  }) {
    return UserInfo(
      name: name ?? this.name,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

/// Provider for current user information
///
/// This is a simple StateProvider for local state.
/// In the future, this can be upgraded to fetch from backend.
final userInfoProvider = StateProvider<UserInfo>((ref) {
  // Default user info - can be updated from settings/auth
  return const UserInfo(
    name: 'Pengguna',
    role: 'Kasir',
    avatarUrl: null,
  );
});
