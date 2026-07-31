import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/auth/presentation/providers/auth_provider.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/login_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/register_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:kasbon_pos/features/auth/presentation/widgets/password_strength_meter.dart';

import '../../../helpers/responsive_helpers.dart';
import 'auth_fixtures.dart';

/// The parts of the auth forms that are behaviour rather than layout.
///
/// `auth_content_width_test.dart` covers where these screens sit and how wide
/// they get. This covers what they do while being typed into, which is where
/// all three of the bugs fixed alongside it lived.
void main() {
  List<Override> overrides() => authProviderOverrides();

  Future<void> pumpLogin(WidgetTester tester) => pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const LoginScreen(),
        providerOverrides: overrides(),
      );

  Future<void> pumpRegister(WidgetTester tester) => pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const RegisterScreen(),
        providerOverrides: overrides(),
      );

  group('validation is per field, not per form', () {
    // `AutovalidateMode.onUserInteraction` set on the `Form` re-validates
    // *every* field the moment *any* field is touched, which is not what the
    // name suggests and not what anyone wants: the first keystroke in the
    // password field decorated the two empty fields above it with "wajib
    // diisi". The modes are on the fields instead. This is the test that says
    // so - moving them back up to the Form fails it.
    testWidgets('typing in one register field leaves the others clean',
        (tester) async {
      await pumpRegister(tester);

      // Index 3 is the password field: nama, email, telepon, password, ...
      await tester.enterText(find.byType(TextField).at(3), 'abc');
      await tester.pumpAndSettle();

      // The field that was typed in reports on itself.
      expect(find.text('Password minimal 8 karakter'), findsOneWidget);

      // The untouched ones say nothing.
      expect(find.text('Nama lengkap wajib diisi'), findsNothing);
      expect(find.text('Email wajib diisi'), findsNothing);
      expect(find.text('Konfirmasi password wajib diisi'), findsNothing);
    });

    testWidgets('a corrected field clears its own error as you type',
        (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextField).first, 'bukan-email');
      await tester.pumpAndSettle();
      expect(find.text('Format email tidak valid'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'toko@kasbon.id');
      await tester.pumpAndSettle();
      expect(find.text('Format email tidak valid'), findsNothing);
    });

    testWidgets('fixing the first password clears the confirm mismatch',
        (tester) async {
      await pumpRegister(tester);

      await tester.enterText(find.byType(TextField).at(3), 'Password123');
      await tester.enterText(find.byType(TextField).at(4), 'Password124');
      await tester.pumpAndSettle();
      expect(find.text('Password tidak cocok'), findsOneWidget);

      // Correcting the *first* field has to clear the error under the second,
      // which the user has no reason to touch again.
      await tester.enterText(find.byType(TextField).at(3), 'Password124');
      await tester.pumpAndSettle();
      expect(find.text('Password tidak cocok'), findsNothing);
    });
  });

  group('password strength meter', () {
    testWidgets('stays hidden until there is a password', (tester) async {
      await pumpRegister(tester);

      final meter = tester.widget<PasswordStrengthMeter>(
        find.byType(PasswordStrengthMeter),
      );
      expect(meter.password, isEmpty);
      // An untouched form should not open covered in unmet requirements.
      expect(find.text('Minimal 8 karakter'), findsNothing);
    });

    testWidgets('grades a password by the rules the validator enforces',
        (tester) async {
      await pumpRegister(tester);

      await tester.enterText(find.byType(TextField).at(3), 'abcdefgh');
      await tester.pumpAndSettle();
      expect(find.text('Lemah'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(3), 'Abcdefgh');
      await tester.pumpAndSettle();
      expect(find.text('Cukup'), findsOneWidget);

      // "Kuat" and a passing validator must be the same condition, or the
      // meter tells the user they are done and the submit disagrees.
      await tester.enterText(find.byType(TextField).at(3), 'Abcdefg1');
      await tester.pumpAndSettle();
      expect(find.text('Kuat'), findsOneWidget);
      expect(find.text('Password minimal 8 karakter'), findsNothing);
    });
  });

  group('failure reporting', () {
    testWidgets('no banner before an attempt has failed', (tester) async {
      await pumpLogin(tester);

      final banner =
          tester.widget<AuthErrorBanner>(find.byType(AuthErrorBanner));
      expect(banner.message, isNull);
    });

    testWidgets('a failed sign-in stays on screen instead of toasting away',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const LoginScreen(),
        providerOverrides: overrides(),
      );

      final element = tester.element(find.byType(LoginScreen));
      final ref = ProviderScope.containerOf(element);
      ref.read(authNotifierProvider.notifier).state = const AuthUiState(
        status: AuthStatus.error,
        errorMessage: 'Email atau password salah',
      );
      await tester.pumpAndSettle();

      expect(find.text('Email atau password salah'), findsOneWidget);

      // The point of a banner over a toast: it is still there some seconds
      // later, while the user is re-reading what they typed.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Email atau password salah'), findsOneWidget);
    });
  });

  group('platform integration', () {
    testWidgets('credential fields are autofillable', (tester) async {
      await pumpLogin(tester);

      // Without hints a password manager has nothing to match on and silently
      // offers nothing, which reads as the OS not supporting autofill.
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(
        fields.first.autofillHints,
        containsAll(<String>[AutofillHints.username, AutofillHints.email]),
      );
      expect(fields.last.autofillHints, contains(AutofillHints.password));

      // And they have to be grouped, or they are saved as unrelated values.
      expect(find.byType(AutofillGroup), findsOneWidget);
    });

    testWidgets('bounded fields do not show a character counter',
        (tester) async {
      await pumpLogin(tester);

      // `maxLength` here is a defensive cap on what reaches the database, not
      // a budget the user is meant to spend. Every auth field used to carry a
      // `0/254` counter purely as a side effect of being bounded.
      expect(find.textContaining('/254'), findsNothing);
      expect(find.textContaining('/128'), findsNothing);
    });
  });
}
