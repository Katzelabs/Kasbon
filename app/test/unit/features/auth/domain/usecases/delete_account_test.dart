import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/errors/auth_error_codes.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/delete_account.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/mock_repositories.dart';

/// The use case behind Pengaturan → Akun → Hapus Akun.
///
/// A pass-through like the rest, so what is pinned is the contract the dialog
/// is written against: the password reaches the repository, and every failure
/// arrives as a `Left` rather than as a thrown exception. The wrong-password
/// case has a second job - its code is what decides whether the dialog blames
/// the password field or shows a server error, so a `Left` that lost the code
/// would be a wrong message rather than no message.
void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  test('passes the password straight through', () async {
    when(() => repository.deleteAccount(password: any(named: 'password')))
        .thenAnswer((_) async => const Right(null));

    final result = await DeleteAccount(repository)(
      const DeleteAccountParams(password: 'rahasia123'),
    );

    expect(result, isA<Right<Failure, void>>());
    verify(() => repository.deleteAccount(password: 'rahasia123')).called(1);
  });

  test('a wrong password comes back as a Left carrying the code', () async {
    when(() => repository.deleteAccount(password: any(named: 'password')))
        .thenAnswer((_) async => const Left(AuthFailure(
              message: 'Password salah',
              code: AuthErrorCodes.wrongPassword,
            )));

    final result = await DeleteAccount(repository)(
      const DeleteAccountParams(password: 'salah'),
    );

    result.fold(
      (failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.code, AuthErrorCodes.wrongPassword);
      },
      (_) => fail('a rejected password must not report success'),
    );
  });

  test('a server failure is a Left too, with a different code', () async {
    when(() => repository.deleteAccount(password: any(named: 'password')))
        .thenAnswer((_) async => const Left(AuthFailure(
              message: 'Gagal menghapus akun. Silakan coba lagi',
              code: '500',
            )));

    final result = await DeleteAccount(repository)(
      const DeleteAccountParams(password: 'rahasia123'),
    );

    result.fold(
      // Not wrongPassword: the dialog would otherwise put a network error under
      // the password field and send the user hunting for a typo.
      (failure) => expect(failure.code, isNot(AuthErrorCodes.wrongPassword)),
      (_) => fail('a failed deletion must not report success'),
    );
  });

  test('params compare by value, so a retry is not a new request', () {
    expect(
      const DeleteAccountParams(password: 'a'),
      const DeleteAccountParams(password: 'a'),
    );
    expect(
      const DeleteAccountParams(password: 'a'),
      isNot(const DeleteAccountParams(password: 'b')),
    );
  });
}
