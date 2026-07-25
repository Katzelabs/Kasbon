import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../../../core/errors/failures.dart';
import '../entities/user_profile.dart';

/// Abstract interface for authentication operations.
abstract class AuthRepository {
  /// Sign in with email and password.
  Future<Either<Failure, UserProfile>> signIn({
    required String email,
    required String password,
  });

  /// Sign up with email, password, and profile info.
  Future<Either<Failure, UserProfile>> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  /// Sign out the current user.
  Future<Either<Failure, void>> signOut();

  /// Get the currently authenticated user's profile, or null if not signed in.
  Future<Either<Failure, UserProfile?>> getCurrentUser();

  /// Stream of authentication state changes.
  Stream<AuthState> authStateChanges();
}
