import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/delete_account.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/get_current_user.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/request_password_reset.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/resend_sign_up_otp.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/reset_password.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_in.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_out.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_up.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/verify_sign_up_otp.dart';
import 'package:kasbon_pos/features/auth/presentation/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

// Bare mocks: the screens only read the notifier's state while building, so
// nothing here is called. Their job is to keep GetIt out of a widget test.
class MockSignIn extends Mock implements SignIn {}

class MockSignUp extends Mock implements SignUp {}

class MockSignOut extends Mock implements SignOut {}

class MockGetCurrentUser extends Mock implements GetCurrentUser {}

class MockVerifySignUpOtp extends Mock implements VerifySignUpOtp {}

class MockResendSignUpOtp extends Mock implements ResendSignUpOtp {}

class MockRequestPasswordReset extends Mock implements RequestPasswordReset {}

class MockResetPassword extends Mock implements ResetPassword {}

class MockDeleteAccount extends Mock implements DeleteAccount {}

/// A fully-mocked [AuthNotifier].
///
/// Every auth widget test wants one, which is why it lives here rather than
/// being restated per file - the notifier takes nine use cases, and each new
/// one used to mean editing every test that builds it.
///
/// [deleteAccount] is the one callers routinely want to stub, since the
/// delete-account dialog is the only screen that drives a use case rather than
/// just reading state, so it is a parameter instead of a fresh bare mock.
AuthNotifier createMockAuthNotifier({DeleteAccount? deleteAccount}) =>
    AuthNotifier(
      signIn: MockSignIn(),
      signUp: MockSignUp(),
      signOut: MockSignOut(),
      getCurrentUser: MockGetCurrentUser(),
      verifySignUpOtp: MockVerifySignUpOtp(),
      resendSignUpOtp: MockResendSignUpOtp(),
      requestPasswordReset: MockRequestPasswordReset(),
      resetPassword: MockResetPassword(),
      deleteAccount: deleteAccount ?? MockDeleteAccount(),
    );

/// Provider overrides pointing [authNotifierProvider] at a mocked notifier.
List<Override> authProviderOverrides({DeleteAccount? deleteAccount}) =>
    <Override>[
      authNotifierProvider.overrideWith(
        (ref) => createMockAuthNotifier(deleteAccount: deleteAccount),
      ),
    ];
