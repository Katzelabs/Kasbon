import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/auth_error_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../models/user_profile_model.dart';

/// Abstract interface for remote authentication operations.
abstract class AuthRemoteDataSource {
  /// Sign in with email and password. Returns the user profile.
  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  });

  /// Sign up with email, password, and profile metadata. Returns the user profile.
  Future<UserProfileModel> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  /// Verify a sign-up with the emailed 6-digit code. Returns the user profile.
  Future<UserProfileModel> verifySignUpOtp({
    required String email,
    required String token,
  });

  /// Resend the sign-up confirmation code.
  Future<void> resendSignUpOtp({required String email});

  /// Email a password-recovery code.
  Future<void> requestPasswordReset({required String email});

  /// Redeem a recovery code and set a new password. Returns the user profile.
  Future<UserProfileModel> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });

  /// Stamp the onboarding-complete marker onto the user's auth metadata.
  Future<void> markOnboardingComplete();

  /// Permanently delete the signed-in account and everything it owns.
  ///
  /// [password] re-authorises the caller; a wrong one throws with
  /// [AuthErrorCodes.wrongPassword] and nothing is deleted. On success the
  /// session is gone - there is no account left to hold one.
  Future<void> deleteAccount({required String password});

  /// Sign out the current user.
  Future<void> signOut();

  /// Get the current user's profile, or null if not authenticated.
  Future<UserProfileModel?> getCurrentUser();

  /// Stream of authentication state changes.
  Stream<sb.AuthState> authStateChanges();
}

/// Implementation of [AuthRemoteDataSource] using Supabase.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClientProvider _clientProvider;

  AuthRemoteDataSourceImpl(this._clientProvider);

  sb.SupabaseClient get _client => _clientProvider.client;

  @override
  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(
          message: 'Login gagal: tidak ada data pengguna',
          code: 'no_user',
        );
      }

      return await _fetchUserProfile(user);
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthErrorMessage(e.message),
        code: _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'Terjadi kesalahan saat login',
        originalError: e,
      );
    }
  }

  @override
  Future<UserProfileModel> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(
          message: 'Pendaftaran gagal: tidak ada data pengguna',
          code: 'no_user',
        );
      }

      // The trigger `handle_new_user()` auto-creates the user_profiles row.
      // We build the model from auth data directly since the profile row
      // may not be available immediately due to trigger timing.
      return UserProfileModel(
        id: user.id,
        email: user.email ?? email,
        fullName: fullName,
        phone: phone,
        tier: 'free',
        createdAt: DateTime.now(),
      );
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthErrorMessage(e.message),
        code: _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'Terjadi kesalahan saat mendaftar',
        originalError: e,
      );
    }
  }

  @override
  Future<UserProfileModel> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: sb.OtpType.signup,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(
          message: 'Verifikasi gagal: tidak ada data pengguna',
          code: 'no_user',
        );
      }

      return await _fetchUserProfile(user);
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthErrorMessage(e.message),
        code: _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'Terjadi kesalahan saat verifikasi',
        originalError: e,
      );
    }
  }

  @override
  Future<void> resendSignUpOtp({required String email}) async {
    try {
      await _client.auth.resend(email: email, type: sb.OtpType.signup);
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthErrorMessage(e.message),
        code: _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } catch (e) {
      throw AuthException(
        message: 'Gagal mengirim ulang kode',
        originalError: e,
      );
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthErrorMessage(e.message),
        code: _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } catch (e) {
      throw AuthException(
        message: 'Gagal mengirim kode reset password',
        originalError: e,
      );
    }
  }

  @override
  Future<UserProfileModel> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      // Redeeming the recovery code signs the user in. The password change
      // below is made against that session - there is no other way to
      // authenticate someone who by definition cannot supply their password.
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: sb.OtpType.recovery,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(
          message: 'Verifikasi gagal: tidak ada data pengguna',
          code: 'no_user',
        );
      }

      await _client.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      return await _fetchUserProfile(user);
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthErrorMessage(e.message),
        code: _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'Terjadi kesalahan saat reset password',
        originalError: e,
      );
    }
  }

  @override
  Future<void> markOnboardingComplete() async {
    try {
      // updateUser merges into raw_user_meta_data rather than replacing it,
      // so full_name and phone survive this write.
      await _client.auth.updateUser(
        sb.UserAttributes(
          data: {
            SupabaseClientProvider.onboardingCompletedAtKey:
                DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _mapAuthErrorMessage(e.message),
        code: _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } catch (e) {
      throw AuthException(
        message: 'Gagal menyimpan status onboarding',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException(
        message: 'Sesi tidak ditemukan. Masuk kembali lalu coba lagi',
        code: 'no_user',
      );
    }

    try {
      // 1. Re-authenticate.
      //
      // A POS device is signed in all day on a counter, so the session alone
      // authorises nothing this destructive. `signInWithPassword` against the
      // account's own address is the only way to check a password with the
      // publishable key; it refreshes the session it replaces, which is
      // harmless and about to be irrelevant.
      await _client.auth.signInWithPassword(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: _isWrongPassword(e.message)
            ? 'Password salah'
            : _mapAuthErrorMessage(e.message),
        code: _isWrongPassword(e.message)
            ? AuthErrorCodes.wrongPassword
            : _mapAuthErrorCode(e.message, e.statusCode),
        originalError: e,
      );
    } catch (e) {
      throw AuthException(
        message: 'Gagal memverifikasi password',
        originalError: e,
      );
    }

    try {
      // 2. Delete, server-side.
      //
      // Removing an `auth.users` row needs the service role, which the app does
      // not have and must not have. The function derives whose account to
      // delete from this request's own token - it takes no uid - so there is
      // nothing here to get wrong. See supabase/functions/delete-account.
      await _client.functions.invoke('delete-account');
    } on sb.FunctionException catch (e) {
      throw AuthException(
        message: 'Gagal menghapus akun. Silakan coba lagi',
        code: '${e.status}',
        originalError: e,
      );
    } catch (e) {
      throw AuthException(
        message: 'Gagal menghapus akun. Periksa koneksi Anda',
        originalError: e,
      );
    }

    // 3. Drop the local session.
    //
    // The account is already gone, so this is about the device: without it the
    // app keeps a token for a user that no longer exists and the router leaves
    // it sitting on the dashboard.
    //
    // gotrue drops the local session and emits `signedOut` *before* it calls
    // the server, and ignores the 403/404 that a deleted user's token earns
    // there - so the redirect happens either way. The catch is for the case
    // that leaves: reporting a throw here would say "deletion failed" about a
    // deletion that succeeded.
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Deliberately ignored - see above.
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on sb.AuthException catch (e) {
      throw AuthException(
        message: 'Gagal keluar. Silakan coba lagi',
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      throw AuthException(
        message: 'Terjadi kesalahan saat keluar',
        originalError: e,
      );
    }
  }

  @override
  Future<UserProfileModel?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      return await _fetchUserProfile(user);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'Gagal memuat profil pengguna',
        originalError: e,
      );
    }
  }

  @override
  Stream<sb.AuthState> authStateChanges() {
    return _clientProvider.onAuthStateChange;
  }

  /// Fetch the user_profiles row for the given auth user.
  Future<UserProfileModel> _fetchUserProfile(sb.User user) async {
    final response = await _client
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      return UserProfileModel.fromJson(
        response,
        email: user.email ?? '',
      );
    }

    // Fallback: profile row might not exist yet (trigger delay).
    // Build from auth metadata.
    final metadata = user.userMetadata ?? {};
    return UserProfileModel(
      id: user.id,
      email: user.email ?? '',
      fullName: (metadata['full_name'] as String?) ?? '',
      phone: metadata['phone'] as String?,
      tier: 'free',
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  /// Whether a re-authentication failed because the password was wrong.
  ///
  /// The address is the account's own and cannot be the thing that is wrong, so
  /// `invalid_credentials` here means exactly one field.
  bool _isWrongPassword(String message) {
    final lower = message.toLowerCase();
    return lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials');
  }

  /// Substitute a semantic code for Supabase's HTTP status where the UI needs
  /// to branch on *which* error this is.
  ///
  /// Returns [fallback] - the status - for everything else, so the code field
  /// keeps its existing meaning for the cases nobody matches on.
  String? _mapAuthErrorCode(String message, String? fallback) {
    final lower = message.toLowerCase();
    if (lower.contains('email not confirmed')) {
      return AuthErrorCodes.emailNotConfirmed;
    }
    if (lower.contains('token has expired or is invalid') ||
        lower.contains('otp_expired') ||
        lower.contains('invalid token')) {
      return AuthErrorCodes.invalidOtp;
    }
    return fallback;
  }

  /// Map Supabase auth error messages to user-friendly Bahasa Indonesia.
  String _mapAuthErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Email atau password salah';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Periksa inbox Anda';
    }
    // A wrong code and an expired one are the same error to Supabase: both
    // come back as otp_expired / "Token has expired or is invalid". Verified
    // against the local stack - do not split this into two messages, or one of
    // them will be a lie half the time. The copy names both possibilities.
    if (lower.contains('token has expired or is invalid') ||
        lower.contains('otp_expired') ||
        lower.contains('invalid token')) {
      return 'Kode salah atau sudah kedaluwarsa. Minta kode baru';
    }
    if (lower.contains('same as the old password') ||
        lower.contains('should be different from the old password')) {
      return 'Password baru harus berbeda dari password lama';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already_exists')) {
      return 'Pendaftaran gagal. Periksa kembali data Anda atau coba login';
    }
    if (lower.contains('weak password') ||
        lower.contains('password is too short') ||
        lower.contains('password_too_short')) {
      return 'Password tidak memenuhi persyaratan keamanan';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Terlalu banyak percobaan. Coba lagi nanti';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Tidak ada koneksi internet';
    }
    return 'Terjadi kesalahan. Silakan coba lagi';
  }
}
