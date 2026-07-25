import '../../domain/entities/user_profile.dart';

/// Data transfer object for UserProfile.
///
/// Maps Supabase `user_profiles` table JSON (snake_case) to the domain entity.
/// Note: `email` is not stored in `user_profiles` — it comes from
/// `Supabase.instance.client.auth.currentUser?.email`.
class UserProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String tier;
  final DateTime createdAt;

  const UserProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.tier = 'free',
    required this.createdAt,
  });

  /// Create from Supabase `user_profiles` row JSON.
  ///
  /// [email] must be provided separately since it lives on `auth.users`,
  /// not the `user_profiles` table.
  factory UserProfileModel.fromJson(
    Map<String, dynamic> json, {
    required String email,
  }) {
    return UserProfileModel(
      id: json['id'] as String,
      email: email,
      fullName: (json['full_name'] as String?) ?? '',
      phone: json['phone'] as String?,
      tier: (json['tier'] as String?) ?? 'free',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to domain entity.
  UserProfile toEntity() {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName,
      phone: phone,
      tier: tier,
      createdAt: createdAt,
    );
  }
}
