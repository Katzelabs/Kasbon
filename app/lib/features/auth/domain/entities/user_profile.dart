import 'package:equatable/equatable.dart';

/// Represents an authenticated user's profile.
class UserProfile extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String tier;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.tier = 'free',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, email];
}
