import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/errors/auth_error_codes.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/delete_account.dart';
import 'package:kasbon_pos/features/backup/domain/entities/backup_metadata.dart';
import 'package:kasbon_pos/features/backup/presentation/providers/backup_provider.dart';
import 'package:kasbon_pos/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/responsive_helpers.dart';
import '../auth/auth_fixtures.dart';

/// The last confirmation before an account stops existing.
///
/// Everything here is about what has to be true *before* `DeleteAccount` is
/// called, because after it there is nothing to assert against - no account, no
/// session, no rows. The two gates are the test surface: a typed word for "I
/// read the list", a password for "I am the owner". A regression that drops
/// either one is not visible in the analyzer and is a one-tap account wipe on a
/// counter-top device.
void main() {
  late MockDeleteAccount deleteAccount;

  /// What the dialog popped with, once it has popped.
  ///
  /// Held out here rather than returned from the helper because it is only
  /// assigned when the dialog closes, which is several pumps after the helper
  /// returns - a returned copy would be null in every test.
  DeleteAccountOutcome? outcome;

  setUpAll(() {
    registerFallbackValue(const DeleteAccountParams(password: 'x'));
  });

  setUp(() {
    deleteAccount = MockDeleteAccount();
    outcome = null;
  });

  /// Pumps the dialog behind a host button, so the result it pops can be
  /// caught in [outcome].
  Future<void> pumpDialog(
    WidgetTester tester, {
    DataCounts counts = const DataCounts(
      products: 42,
      transactions: 312,
      categories: 7,
    ),
  }) async {
    await pumpAtWidth(
      tester,
      ResponsiveWidths.compact,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            outcome = await DeleteAccountDialog.show(context);
          },
          child: const Text('open'),
        ),
      ),
      providerOverrides: [
        ...authProviderOverrides(deleteAccount: deleteAccount),
        dataCountsProvider.overrideWith((ref) async => counts),
      ],
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder deleteButton() => find.widgetWithText(ModernButton, 'Hapus Akun');
  Finder passwordField() => find.widgetWithText(ModernTextField, 'Password');
  Finder confirmField() => find.widgetWithText(ModernTextField, 'Ketik HAPUS');

  Future<void> fill(
    WidgetTester tester, {
    String password = 'rahasia123',
    String word = 'HAPUS',
  }) async {
    await tester.enterText(passwordField(), password);
    await tester.enterText(confirmField(), word);
    await tester.pump();
  }

  bool isEnabled(WidgetTester tester) =>
      tester.widget<ModernButton>(deleteButton()).onPressed != null;

  testWidgets('names what is destroyed, with counts', (tester) async {
    await pumpDialog(tester);

    // "Semua data Anda" is true and means nothing. The numbers are the part
    // that makes someone stop, and the store requirement is specifically that
    // the confirmation says what goes.
    expect(find.text('312'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('Foto produk'), findsOneWidget);
  });

  testWidgets('the delete button starts disabled', (tester) async {
    await pumpDialog(tester);

    expect(isEnabled(tester), isFalse);
  });

  testWidgets('the typed word alone does not unlock it', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(confirmField(), 'HAPUS');
    await tester.pump();

    // The password gate is the one that matters on a device left signed in on
    // a shop counter: a passer-by can read the word off the screen.
    expect(isEnabled(tester), isFalse);
  });

  testWidgets('the password alone does not unlock it', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(passwordField(), 'rahasia123');
    await tester.pump();

    expect(isEnabled(tester), isFalse);
  });

  testWidgets('a near-miss of the word does not unlock it', (tester) async {
    await pumpDialog(tester);
    await fill(tester, word: 'hapus');

    // Case-sensitive on purpose. Lowercase is what autocorrect produces from a
    // half-hearted tap; typing it in capitals is a decision.
    expect(isEnabled(tester), isFalse);
  });

  testWidgets('both gates together unlock it', (tester) async {
    await pumpDialog(tester);
    await fill(tester);

    expect(isEnabled(tester), isTrue);
  });

  testWidgets('deleting nothing is what happens on cancel', (tester) async {
    await pumpDialog(tester);
    await fill(tester);

    await tester.tap(find.widgetWithText(ModernButton, 'Batal'));
    await tester.pumpAndSettle();

    verifyNever(() => deleteAccount(any()));
    expect(outcome, DeleteAccountOutcome.cancelled);
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });

  testWidgets('a wrong password is shown against the password field',
      (tester) async {
    when(() => deleteAccount(any())).thenAnswer(
      (_) async => const Left(AuthFailure(
        message: 'Password salah',
        code: AuthErrorCodes.wrongPassword,
      )),
    );

    await pumpDialog(tester);
    await fill(tester, password: 'salah');
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    // Still open, and specific about which field was wrong - a banner saying
    // "gagal menghapus akun" would send the user looking for a server problem.
    expect(find.byType(DeleteAccountDialog), findsOneWidget);
    final field = tester.widget<ModernTextField>(passwordField());
    expect(field.errorText, 'Password salah');
  });

  testWidgets('any other failure is shown as a strip, not on the field',
      (tester) async {
    when(() => deleteAccount(any())).thenAnswer(
      (_) async => const Left(AuthFailure(
        message: 'Gagal menghapus akun. Periksa koneksi Anda',
        code: '500',
      )),
    );

    await pumpDialog(tester);
    await fill(tester);
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Gagal menghapus akun. Periksa koneksi Anda'),
      findsOneWidget,
    );
    expect(tester.widget<ModernTextField>(passwordField()).errorText, isNull);
  });

  testWidgets('typing again clears the last failure', (tester) async {
    when(() => deleteAccount(any())).thenAnswer(
      (_) async => const Left(AuthFailure(
        message: 'Password salah',
        code: AuthErrorCodes.wrongPassword,
      )),
    );

    await pumpDialog(tester);
    await fill(tester, password: 'salah');
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    await tester.enterText(passwordField(), 'benar123');
    await tester.pump();

    // An error left under a field the user has already corrected reads as a
    // live complaint about the value now in it.
    expect(tester.widget<ModernTextField>(passwordField()).errorText, isNull);
  });

  testWidgets('a successful deletion passes the password through and pops',
      (tester) async {
    when(() => deleteAccount(any())).thenAnswer((_) async => const Right(null));

    await pumpDialog(tester);
    await fill(tester, password: 'rahasia123');
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    final captured = verify(() => deleteAccount(captureAny())).captured.single
        as DeleteAccountParams;
    expect(captured.password, 'rahasia123');
    expect(outcome, DeleteAccountOutcome.deleted);
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });

  testWidgets('the backup offer leaves without deleting', (tester) async {
    await pumpDialog(tester);
    await fill(tester);

    // The offer sits above the password field in a scrolling dialog, which on
    // a phone-height view is off screen once the fields are filled.
    final offer = find.widgetWithText(ModernButton, 'Buat Backup Dulu');
    await tester.ensureVisible(offer);
    await tester.pumpAndSettle();
    await tester.tap(offer);
    await tester.pumpAndSettle();

    // The caller routes to the backup screen on this outcome. Deleting first
    // and exporting afterwards is not a thing that can be offered.
    verifyNever(() => deleteAccount(any()));
    expect(outcome, DeleteAccountOutcome.backupRequested);
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });
}
