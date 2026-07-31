import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/request_password_reset.dart';
import '../../domain/usecases/resend_sign_up_otp.dart';
import '../../domain/usecases/reset_password.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/verify_sign_up_otp.dart';

// ---------------------------------------------------------------------------
// Stream / read-only providers
// ---------------------------------------------------------------------------

/// Stream of Supabase auth state changes (for router redirect logic).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current Supabase session (synchronous read).
///
/// Watches [authStateProvider] for the same reason `userInfoProvider` does:
/// without it this reads the session once, caches it for the life of the app,
/// and keeps handing out the previous user's session after a sign-out.
final currentSessionProvider = Provider<Session?>((ref) {
  try {
    ref.watch(authStateProvider);
  } catch (_) {
    return null;
  }

  return Supabase.instance.client.auth.currentSession;
});

// ---------------------------------------------------------------------------
// Auth notifier (login / signup / logout actions)
// ---------------------------------------------------------------------------

/// Provides the [AuthNotifier] for performing auth mutations.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthUiState>((ref) {
  return AuthNotifier(
    signIn: getIt<SignIn>(),
    signUp: getIt<SignUp>(),
    signOut: getIt<SignOut>(),
    getCurrentUser: getIt<GetCurrentUser>(),
    verifySignUpOtp: getIt<VerifySignUpOtp>(),
    resendSignUpOtp: getIt<ResendSignUpOtp>(),
    requestPasswordReset: getIt<RequestPasswordReset>(),
    resetPassword: getIt<ResetPassword>(),
  );
});

/// Simplified auth UI state.
enum AuthStatus {
  initial,
  loading,
  authenticated,

  /// Registered, but the emailed code has not been entered yet.
  ///
  /// Distinct from [authenticated] because sign-up returns no session while
  /// email confirmation is enabled - there is a user, and nothing they can do
  /// with it until they verify.
  pendingVerification,
  unauthenticated,
  error,
}

/// State held by [AuthNotifier].
///
/// Named `AuthUiState` rather than `AuthState` because supabase_flutter
/// exports its own `AuthState`, used by [authStateProvider] above.
class AuthUiState {
  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  /// The failure's code, for callers that must branch on *which* error this
  /// was rather than only show it. See [AuthErrorCodes].
  final String? errorCode;

  const AuthUiState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.errorCode,
  });

  /// Note that [errorMessage] and [errorCode] are *not* merged with `??`: any
  /// copy that does not restate them clears them. Deliberate - every mutation
  /// below opens by clearing the last failure, and an error that outlived the
  /// attempt that produced it would be shown against the next one.
  AuthUiState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? errorMessage,
    String? errorCode,
  }) {
    return AuthUiState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }
}

/// Handles authentication actions (sign in, sign up, sign out, fetch profile).
class AuthNotifier extends StateNotifier<AuthUiState> {
  final SignIn _signIn;
  final SignUp _signUp;
  final SignOut _signOut;
  final GetCurrentUser _getCurrentUser;
  final VerifySignUpOtp _verifySignUpOtp;
  final ResendSignUpOtp _resendSignUpOtp;
  final RequestPasswordReset _requestPasswordReset;
  final ResetPassword _resetPassword;

  AuthNotifier({
    required SignIn signIn,
    required SignUp signUp,
    required SignOut signOut,
    required GetCurrentUser getCurrentUser,
    required VerifySignUpOtp verifySignUpOtp,
    required ResendSignUpOtp resendSignUpOtp,
    required RequestPasswordReset requestPasswordReset,
    required ResetPassword resetPassword,
  })  : _signIn = signIn,
        _signUp = signUp,
        _signOut = signOut,
        _getCurrentUser = getCurrentUser,
        _verifySignUpOtp = verifySignUpOtp,
        _resendSignUpOtp = resendSignUpOtp,
        _requestPasswordReset = requestPasswordReset,
        _resetPassword = resetPassword,
        super(const AuthUiState());

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
          errorCode: failure.code,
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
          errorCode: failure.code,
        );
        return false;
      },
      (user) {
        // Not `authenticated`: with email confirmation on, sign-up returns a
        // user but no session. The account exists and can do nothing until the
        // emailed code is entered.
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          user: user,
        );
        return true;
      },
    );
  }

  /// Confirm a sign-up with the emailed 6-digit code. Signs the user in.
  Future<bool> verifyOtp({
    required String email,
    required String token,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _verifySignUpOtp(VerifySignUpOtpParams(
      email: email,
      token: token,
    ));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
          errorCode: failure.code,
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

  /// Send a fresh sign-up confirmation code.
  Future<bool> resendOtp({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _resendSignUpOtp(ResendSignUpOtpParams(email: email));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
          errorCode: failure.code,
        );
        return false;
      },
      (_) {
        state = state.copyWith(status: AuthStatus.pendingVerification);
        return true;
      },
    );
  }

  /// Email a password-recovery code.
  Future<bool> requestPasswordReset({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _requestPasswordReset(
      RequestPasswordResetParams(email: email),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
          errorCode: failure.code,
        );
        return false;
      },
      (_) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return true;
      },
    );
  }

  /// Redeem a recovery code and set a new password. Signs the user in.
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final result = await _resetPassword(ResetPasswordParams(
      email: email,
      token: token,
      newPassword: newPassword,
    ));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: failure.message,
          errorCode: failure.code,
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
          errorCode: failure.code,
        );
      },
      (_) {
        state = const AuthUiState(status: AuthStatus.unauthenticated);
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
          state = const AuthUiState(status: AuthStatus.unauthenticated);
        }
      },
    );
  }
}
