import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/errors/auth_error_codes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_scaffold.dart';

/// Login screen with email and password authentication.
///
/// Layout, background and width clamp all live in [AuthScaffold], which
/// register shares - see the notes there.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Held explicitly rather than left to `nextFocus`, which walks the traversal
  // order and will happily land on the visibility toggle - a focusable button
  // sitting between the two fields.
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    // Dismiss the keyboard first, so a failure banner is not rendered behind
    // it on a phone.
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    final success = await ref.read(authNotifierProvider.notifier).login(
          email: email,
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      // Tells the platform the credential was accepted, which is what prompts
      // the offer to save it. Without this the autofill hints below let a
      // password manager *fill* the form but never learn a new login.
      TextInput.finishAutofillContext();
      context.go(AppRoutes.dashboard);
      return;
    }

    // An unverified account is not a wrong password, and telling someone their
    // credentials were right but unusable, with no way to act on it, is a dead
    // end. Send them to the screen that can finish the job.
    if (ref.read(authNotifierProvider).errorCode ==
        AuthErrorCodes.emailNotConfirmed) {
      context.go(AppRoutes.verifyEmailPath(email));
    }
    // Any other failure stays on screen in the banner instead of a toast - see
    // [AuthErrorBanner].
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return AuthScaffold(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(),
              const SizedBox(height: AppDimensions.spacing40),
              const AuthFormTitle(
                title: 'Masuk ke Akun Anda',
                subtitle: 'Kelola penjualan dan keuntungan toko Anda',
              ),
              const SizedBox(height: AppDimensions.spacing24),
              ModernTextField(
                label: 'Email',
                hint: 'contoh@email.com',
                controller: _emailController,
                focusNode: _emailFocus,
                leading: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                maxLength: 254,
                validator: Validators.email,
                enabled: !isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              ModernPasswordField(
                label: 'Password',
                hint: 'Masukkan password',
                controller: _passwordController,
                focusNode: _passwordFocus,
                leading: const Icon(Icons.lock_outlined),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onLogin(),
                autofillHints: const [AutofillHints.password],
                maxLength: 128,
                // Deliberately *not* Validators.password: the strength rules
                // belong on registration. Applying them here rejects every
                // account created before they existed, at the one screen where
                // the user cannot do anything about it.
                validator: _validatePassword,
                enabled: !isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Align(
                alignment: Alignment.centerRight,
                child: ModernButton.text(
                  onPressed: isLoading
                      ? null
                      : () => context.go(AppRoutes.forgotPassword),
                  child: Text(
                    'Lupa password?',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing16),
              AuthErrorBanner(
                message: authState.status == AuthStatus.error
                    ? authState.errorMessage
                    : null,
              ),
              ModernButton.primary(
                onPressed: isLoading ? null : _onLogin,
                isLoading: isLoading,
                size: ModernSize.large,
                fullWidth: true,
                child: const Text('Masuk'),
              ),
              const SizedBox(height: AppDimensions.spacing16),
              // A Wrap, not a Row: at a large text scale the sentence and the
              // link together are wider than a phone, and a Row overflows
              // where this drops the link onto its own line.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Belum punya akun? ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  ModernButton.text(
                    onPressed:
                        isLoading ? null : () => context.go(AppRoutes.register),
                    child: Text(
                      'Daftar',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    return null;
  }
}
