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

  /// Confirm a sign-up with the 6-digit code emailed to [email].
  ///
  /// On success the user is signed in - verifying the code is what mints the
  /// first session, since sign-up itself returns none while email confirmation
  /// is enabled.
  Future<Either<Failure, UserProfile>> verifySignUpOtp({
    required String email,
    required String token,
  });

  /// Send a fresh sign-up confirmation code to [email].
  Future<Either<Failure, void>> resendSignUpOtp({required String email});

  /// Email a password-recovery code to [email].
  ///
  /// Succeeds whether or not an account exists, so that the caller cannot use
  /// it to discover which addresses are registered.
  Future<Either<Failure, void>> requestPasswordReset({required String email});

  /// Redeem a recovery code and set a new password.
  ///
  /// The user is signed in afterwards: the code establishes the session that
  /// the password change is then made against.
  Future<Either<Failure, UserProfile>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });

  /// Record that this user has finished the onboarding wizard.
  Future<Either<Failure, void>> markOnboardingComplete();

  /// Sign out the current user.
  Future<Either<Failure, void>> signOut();

  /// Get the currently authenticated user's profile, or null if not signed in.
  Future<Either<Failure, UserProfile?>> getCurrentUser();

  /// Stream of authentication state changes.
  Stream<AuthState> authStateChanges();
}
