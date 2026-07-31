import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_scaffold.dart';

/// Asks which account to recover, and sends it a code.
///
/// Moves on to [ResetPasswordScreen] whether or not the address has an account.
/// Supabase answers an unknown email with a plain success for a reason - a
/// screen that said "email tidak terdaftar" would turn this form into a way to
/// enumerate who has an account here. The user with a typo finds out the same
/// way as the user with no account: no code arrives.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    final sent = await ref
        .read(authNotifierProvider.notifier)
        .requestPasswordReset(email: email);

    if (!mounted) return;

    if (sent) {
      context.go(AppRoutes.resetPasswordPath(email));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return AuthScaffold(
      leading: ModernIconButton(
        icon: Icons.arrow_back,
        onPressed: isLoading ? null : () => context.go(AppRoutes.login),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader.compact(),
            const SizedBox(height: AppDimensions.spacing32),
            const AuthFormTitle(
              title: 'Lupa Password',
              subtitle: 'Masukkan email Anda, kami kirim kode untuk membuat '
                  'password baru',
            ),
            const SizedBox(height: AppDimensions.spacing24),
            ModernTextField(
              label: 'Email',
              hint: 'contoh@email.com',
              controller: _emailController,
              focusNode: _emailFocus,
              leading: const Icon(Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onSubmit(),
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              maxLength: 254,
              autofocus: true,
              validator: Validators.email,
              enabled: !isLoading,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: AppDimensions.spacing24),
            AuthErrorBanner(
              message: authState.status == AuthStatus.error
                  ? authState.errorMessage
                  : null,
            ),
            ModernButton.primary(
              onPressed: isLoading ? null : _onSubmit,
              isLoading: isLoading,
              size: ModernSize.large,
              fullWidth: true,
              child: const Text('Kirim Kode'),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Ingat password Anda? ',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                ModernButton.text(
                  onPressed:
                      isLoading ? null : () => context.go(AppRoutes.login),
                  child: Text(
                    'Masuk',
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
    );
  }
}
