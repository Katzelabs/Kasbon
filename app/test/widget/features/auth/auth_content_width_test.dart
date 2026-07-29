import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/responsive/modern_content_column.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/get_current_user.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_in.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_out.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_up.dart';
import 'package:kasbon_pos/features/auth/presentation/providers/auth_provider.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/login_screen.dart';
import 'package:kasbon_pos/features/auth/presentation/screens/register_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/responsive_helpers.dart';

// The screens only read the notifier's state while building; nothing here is
// ever called, so bare mocks are enough to keep GetIt out of a layout test.
class _MockSignIn extends Mock implements SignIn {}

class _MockSignUp extends Mock implements SignUp {}

class _MockSignOut extends Mock implements SignOut {}

class _MockGetCurrentUser extends Mock implements GetCurrentUser {}

/// The auth screens sit outside the shell, so nothing above them caps their
/// width. They used to cap themselves with a hand-rolled
/// `ConstrainedBox(maxWidth: 400)`, which clamped the pixels but left the
/// breakpoint scope describing the *window* - so a child asking "have I got
/// room for two columns?" inside a 400dp form on a 1600dp monitor was told yes.
///
/// `ModernContentColumn.form` fixes both halves at once, and these tests pin
/// the clamp so a later refactor cannot quietly drop it.
void main() {
  final overrides = <Override>[
    authNotifierProvider.overrideWith(
      (ref) => AuthNotifier(
        signIn: _MockSignIn(),
        signUp: _MockSignUp(),
        signOut: _MockSignOut(),
        getCurrentUser: _MockGetCurrentUser(),
      ),
    ),
  ];

  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
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
