import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/widgets/otp_resend_button.dart';

import '../../../helpers/responsive_helpers.dart';
import 'auth_fixtures.dart';

/// The verification screen's two jobs: take six digits, and stop the user
/// hammering the resend button.
void main() {
  Future<void> pumpVerify(WidgetTester tester) => pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const VerifyEmailScreen(email: 'toko@kasbon.id'),
        providerOverrides: authProviderOverrides(),
        settle: false,
      );

  testWidgets('shows which address the code went to', (tester) async {
    await pumpVerify(tester);

    // Without this the screen is unfalsifiable: a user who mistyped their
    // email waits for a code that went somewhere else, with nothing on screen
    // to tell them so.
    expect(find.text('toko@kasbon.id'), findsOneWidget);
  });

  testWidgets('the code field takes digits only', (tester) async {
    await pumpVerify(tester);

    await tester.enterText(find.byType(TextField).first, '12a3b4');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, '1234');
    expect(field.maxLength, 6);
  });

  testWidgets('the code field advertises itself for OTP autofill',
      (tester) async {
    await pumpVerify(tester);

    // oneTimeCode is what lets iOS offer the code straight from the mail
    // notification. Without it the user retypes six digits by hand.
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
  });

  testWidgets('rejects a short code before calling anything', (tester) async {
    await pumpVerify(tester);

    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();

    expect(find.text('Kode OTP harus 6 digit angka'), findsOneWidget);
  });

  group('resend cooldown', () {
    testWidgets('opens counting down, not ready to fire', (tester) async {
      await pumpVerify(tester);

      // The screen is reached *because* a code was just sent. A live button on
      // arrival invites a second request before the first email lands, which
      // the server answers with a rate-limit error that reads as a bug.
      expect(find.byType(OtpResendButton), findsOneWidget);
      expect(find.textContaining('Kirim ulang kode dalam'), findsOneWidget);
      expect(find.text('Kirim ulang kode'), findsNothing);
    });

    testWidgets('counts down and then offers the button', (tester) async {
      await pumpVerify(tester);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Kirim ulang kode dalam 30 detik'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Kirim ulang kode'), findsOneWidget);
      expect(find.textContaining('Kirim ulang kode dalam'), findsNothing);
    });

    testWidgets('the timer does not outlive the screen', (tester) async {
      await pumpVerify(tester);

      // A Timer.periodic still ticking after dispose calls setState on a dead
      // State and throws - which surfaces as a test-only crash long after the
      // screen that caused it is gone.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 65));

      expect(tester.takeException(), isNull);
    });
  });
}
