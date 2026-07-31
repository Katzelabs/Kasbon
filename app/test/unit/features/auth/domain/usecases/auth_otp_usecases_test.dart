import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/errors/auth_error_codes.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/auth/domain/entities/user_profile.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/mark_onboarding_complete.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/request_password_reset.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/resend_sign_up_otp.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/reset_password.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/verify_sign_up_otp.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/mock_repositories.dart';

/// The use cases behind email verification, password recovery and the
/// onboarding marker.
///
/// Each is a thin pass-through, so what is worth pinning is that the arguments
/// arrive where they are supposed to and that failures come back as `Left`
/// rather than as thrown exceptions - the repository contract the whole
/// presentation layer is written against.
void main() {
  late MockAuthRepository repository;

  final profile = UserProfile(
    id: 'user-1',
    email: 'toko@kasbon.id',
    fullName: 'Bu Sri',
    tier: 'free',
    createdAt: DateTime(2026, 7, 31),
  );

  setUp(() {
    repository = MockAuthRepository();
  });

  group('VerifySignUpOtp', () {
    test('passes the email and code straight through', () async {
      when(() => repository.verifySignUpOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          )).thenAnswer((_) async => Right(profile));

      final result = await VerifySignUpOtp(repository)(
        const VerifySignUpOtpParams(
          email: 'toko@kasbon.id',
          token: '123456',
        ),
      );

      expect(result, isA<Right<Failure, UserProfile>>());
      verify(() => repository.verifySignUpOtp(
            email: 'toko@kasbon.id',
            token: '123456',
          )).called(1);
    });

    test('a rejected code comes back as a Left carrying the code', () async {
      when(() => repository.verifySignUpOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          )).thenAnswer((_) async => const Left(AuthFailure(
            message: 'Kode salah atau sudah kedaluwarsa. Minta kode baru',
            code: AuthErrorCodes.invalidOtp,
          )));

      final result = await VerifySignUpOtp(repository)(
        const VerifySignUpOtpParams(
          email: 'toko@kasbon.id',
          token: '000000',
        ),
      );

      expect(
        result.fold((f) => f.code, (_) => null),
        AuthErrorCodes.invalidOtp,
      );
    });
  });

  group('ResendSignUpOtp', () {
    test('asks for a fresh code for the given address', () async {
      when(() => repository.resendSignUpOtp(email: any(named: 'email')))
          .thenAnswer((_) async => const Right(null));

      final result = await ResendSignUpOtp(repository)(
        const ResendSignUpOtpParams(email: 'toko@kasbon.id'),
      );

      expect(result, isA<Right<Failure, void>>());
      verify(() => repository.resendSignUpOtp(email: 'toko@kasbon.id'))
          .called(1);
    });
  });

  group('RequestPasswordReset', () {
    test('succeeds for an address with no account', () async {
      // Supabase answers an unknown email with a plain success so that this
      // form cannot be used to discover who has an account. If the use case
      // ever started reporting a failure here, the UI would leak exactly what
      // the server went out of its way to hide.
      when(() => repository.requestPasswordReset(email: any(named: 'email')))
          .thenAnswer((_) async => const Right(null));

      final result = await RequestPasswordReset(repository)(
        const RequestPasswordResetParams(email: 'nobody@nowhere.id'),
      );

      expect(result, isA<Right<Failure, void>>());
    });
  });

  group('ResetPassword', () {
    test('forwards the code and the new password together', () async {
      when(() => repository.resetPassword(
            email: any(named: 'email'),
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          )).thenAnswer((_) async => Right(profile));

      final result = await ResetPassword(repository)(
        const ResetPasswordParams(
          email: 'toko@kasbon.id',
          token: '654321',
          newPassword: 'Password123',
        ),
      );

      expect(result, isA<Right<Failure, UserProfile>>());
      verify(() => repository.resetPassword(
            email: 'toko@kasbon.id',
            token: '654321',
            newPassword: 'Password123',
          )).called(1);
    });

    test('a bad recovery code does not change the password', () async {
      when(() => repository.resetPassword(
            email: any(named: 'email'),
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          )).thenAnswer((_) async => const Left(AuthFailure(
            message: 'Kode salah atau sudah kedaluwarsa. Minta kode baru',
            code: AuthErrorCodes.invalidOtp,
          )));

      final result = await ResetPassword(repository)(
        const ResetPasswordParams(
          email: 'toko@kasbon.id',
          token: '000000',
          newPassword: 'Password123',
        ),
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('MarkOnboardingComplete', () {
    test('takes no parameters and delegates', () async {
      when(() => repository.markOnboardingComplete())
          .thenAnswer((_) async => const Right(null));

      final result = await MarkOnboardingComplete(repository)();

      expect(result, isA<Right<Failure, void>>());
      verify(() => repository.markOnboardingComplete()).called(1);
    });

    test('a failed write is reported, not swallowed', () async {
      // The wizard navigates only when this succeeds. If a failure were
      // reported as success the marker would never land, and the router's gate
      // would drop the user back into onboarding on their next launch.
      when(() => repository.markOnboardingComplete()).thenAnswer(
        (_) async => const Left(
          AuthFailure(message: 'Gagal menyimpan status onboarding'),
        ),
      );

      final result = await MarkOnboardingComplete(repository)();

      expect(result.isLeft(), isTrue);
    });
  });
}
