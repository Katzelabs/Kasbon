import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/responsive/modern_content_column.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/login_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/register_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/verify_email_screen.dart';

import '../../../helpers/responsive_helpers.dart';
import 'auth_fixtures.dart';

/// The auth screens sit outside the shell, so nothing above them caps their
/// width. They used to cap themselves with a hand-rolled
/// `ConstrainedBox(maxWidth: 400)`, which clamped the pixels but left the
/// breakpoint scope describing the *window* - so a child asking "have I got
/// room for two columns?" inside a 400dp form on a 1600dp monitor was told yes.
///
/// `ModernContentColumn.form` fixes both halves at once, and these tests pin
/// the clamp so a later refactor cannot quietly drop it.
void main() {
  final overrides = authProviderOverrides();

  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'verifyEmail': const VerifyEmailScreen(email: 'test@kasbon.id'),
    'forgotPassword': const ForgotPasswordScreen(),
    'resetPassword': const ResetPasswordScreen(email: 'test@kasbon.id'),
  };

  for (final entry in screens.entries) {
    for (final width in ResponsiveWidths.all) {
      testWidgets(
        '${entry.key} renders at ${ResponsiveWidths.label(width)}',
        (tester) async {
          await pumpScreenAtWidth(
            tester,
            width,
            entry.value,
            providerOverrides: overrides,
          );

          expect(find.byType(TextField), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('${entry.key} clamps to form width on a wide window',
        (tester) async {
      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.large,
        entry.value,
        providerOverrides: overrides,
      );

      final column = tester.widget<ModernContentColumn>(
        find.byType(ModernContentColumn),
      );
      expect(column.width, ContentWidth.form);

      // The fields themselves are what the user sees widen; assert on those
      // rather than on the wrapper, so the test still means something if the
      // padding or the nesting changes.
      final field = tester.getSize(find.byType(TextField).first);
      expect(
        field.width,
        lessThanOrEqualTo(ContentWidth.form.maxWidth),
        reason: 'a 1600dp window should not give the email field 1600dp',
      );
    });

    testWidgets('${entry.key} still fills a phone', (tester) async {
      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        entry.value,
        providerOverrides: overrides,
      );

      // The clamp is a maximum, not a fixed width - on a 375dp phone the form
      // should still use the room it has, less the tier padding.
      final field = tester.getSize(find.byType(TextField).first);
      expect(field.width, greaterThan(300));
    });
  }
}
