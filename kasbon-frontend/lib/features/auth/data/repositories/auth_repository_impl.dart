import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementation of [AuthRepository] that delegates to [AuthRemoteDataSource].
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, UserProfile>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _remoteDataSource.signIn(
        email: email,
        password: password,
      );
      return Right(model.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return const Left(
        AuthFailure(message: 'Terjadi kesalahan saat login'),
      );
    }
  }

  @override
  Future<Either<Failure, UserProfile>> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final model = await _remoteDataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      return Right(model.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return const Left(
        AuthFailure(message: 'Terjadi kesalahan saat mendaftar'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return const Left(
        AuthFailure(message: 'Terjadi kesalahan saat keluar'),
      );
    }
  }

  @override
  Future<Either<Failure, UserProfile?>> getCurrentUser() async {
    try {
      final model = await _remoteDataSource.getCurrentUser();
      return Right(model?.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return const Left(
        AuthFailure(message: 'Gagal memuat profil pengguna'),
      );
    }
  }

  @override
  Stream<AuthState> authStateChanges() {
    return _remoteDataSource.authStateChanges();
  }
}
