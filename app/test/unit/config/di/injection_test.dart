import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/get_current_user.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/mark_onboarding_complete.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/request_password_reset.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/resend_sign_up_otp.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/reset_password.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_in.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_out.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/sign_up.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/verify_sign_up_otp.dart';
import 'package:kasbon_pos/features/categories/domain/usecases/create_category.dart';
import 'package:kasbon_pos/features/products/domain/usecases/create_product.dart';
import 'package:kasbon_pos/features/products/domain/usecases/get_paginated_products.dart';
import 'package:kasbon_pos/features/receipt/domain/usecases/get_shop_settings.dart';
import 'package:kasbon_pos/features/settings/domain/usecases/update_shop_settings.dart';

/// Every use case a provider resolves out of GetIt must actually be in there.
///
/// This is the one class of breakage the rest of the suite cannot see. Widget
/// tests override the notifiers wholesale precisely so GetIt stays out of them,
/// so adding a use case to a notifier and forgetting the matching
/// `registerLazySingleton` leaves 1000+ green tests and an app that throws the
/// instant the screen is opened.
///
/// Resolving is safe without `Supabase.initialize`: registration is lazy, and
/// constructing a datasource only stores a `SupabaseClientProvider`, which does
/// not touch `Supabase.instance` until a query is actually run.
void main() {
  setUpAll(() async {
    await configureDependencies();
  });

  tearDownAll(() => getIt.reset());

  test('the auth notifier can build', () {
    // The exact set read by `authNotifierProvider`.
    expect(getIt<SignIn>(), isA<SignIn>());
    expect(getIt<SignUp>(), isA<SignUp>());
    expect(getIt<SignOut>(), isA<SignOut>());
    expect(getIt<GetCurrentUser>(), isA<GetCurrentUser>());
    expect(getIt<VerifySignUpOtp>(), isA<VerifySignUpOtp>());
    expect(getIt<ResendSignUpOtp>(), isA<ResendSignUpOtp>());
    expect(getIt<RequestPasswordReset>(), isA<RequestPasswordReset>());
    expect(getIt<ResetPassword>(), isA<ResetPassword>());
  });

  test('the onboarding notifier can build', () {
    // The exact set read by `onboardingProvider`.
    expect(getIt<GetShopSettings>(), isA<GetShopSettings>());
    expect(getIt<UpdateShopSettings>(), isA<UpdateShopSettings>());
    expect(getIt<CreateCategory>(), isA<CreateCategory>());
    expect(getIt<CreateProduct>(), isA<CreateProduct>());
    expect(getIt<MarkOnboardingComplete>(), isA<MarkOnboardingComplete>());
  });

  test('the setup checklist can build', () {
    expect(getIt<GetPaginatedProducts>(), isA<GetPaginatedProducts>());
    expect(getIt<GetShopSettings>(), isA<GetShopSettings>());
  });
}
