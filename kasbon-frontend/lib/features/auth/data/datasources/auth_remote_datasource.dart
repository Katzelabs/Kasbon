import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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
        code: e.statusCode,
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
        code: e.statusCode,
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
