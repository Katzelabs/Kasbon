import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';

// ---------------------------------------------------------------------------
// Stream / read-only providers
// ---------------------------------------------------------------------------

/// Stream of Supabase auth state changes (for router redirect logic).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current Supabase session (synchronous read).
final currentSessionProvider = Provider<Session?>((ref) {
  return Supabase.instance.client.auth.currentSession;
});

// ---------------------------------------------------------------------------
// Auth notifier (login / signup / logout actions)
// ---------------------------------------------------------------------------

/// Provides the [AuthNotifier] for performing auth mutations.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState_>((ref) {
  return AuthNotifier(
    signIn: getIt<SignIn>(),
    signUp: getIt<SignUp>(),
    signOut: getIt<SignOut>(),
    getCurrentUser: getIt<GetCurrentUser>(),
  );
});

/// Simplified auth UI state.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// State held by [AuthNotifier].
class AuthState_ {
  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  const AuthState_({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState_ copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? errorMessage,
  }) {
    return AuthState_(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

/// Handles authentication actions (sign in, sign up, sign out, fetch profile).
class AuthNotifier extends StateNotifier<AuthState_> {
  final SignIn _signIn;
  final SignUp _signUp;
  final SignOut _signOut;
  final GetCurrentUser _getCurrentUser;

  AuthNotifier({
    required SignIn signIn,
    required SignUp signUp,
    required SignOut signOut,
    required GetCurrentUser getCurrentUser,
  })  : _signIn = signIn,
        _signUp = signUp,
        _signOut = signOut,
        _getCurrentUser = getCurrentUser,
        super(const AuthState_());

  /// Attempt to sign in with email and password.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _signIn(SignInParams(
      email: email,
      password: password,
    ));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
        return true;
      },
    );
  }

  /// Attempt to register a new account.
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _signUp(SignUpParams(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    ));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
        return false;
      },
      (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
        return true;
      },
    );
  }

  /// Sign out the current user.
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _signOut();

    result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
        );
      },
      (_) {
        state = const AuthState_(status: AuthStatus.unauthenticated);
      },
    );
  }

  /// Load the current user profile (e.g., on app start).
  Future<void> loadCurrentUser() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _getCurrentUser();

    result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: failure.message,
        );
      },
      (user) {
        if (user != null) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
          );
        } else {
          state = const AuthState_(status: AuthStatus.unauthenticated);
        }
      },
    );
  }
}
