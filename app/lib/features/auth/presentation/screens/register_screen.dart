import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/password_strength_meter.dart';

/// Registration screen for new user accounts.
///
/// Layout, background and width clamp all live in [AuthScaffold], which login
/// shares - see the notes there.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Explicit, so `next` moves between fields rather than into whichever
  // visibility toggle happens to sit between them in traversal order.
  final _fullNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  /// Mirrors the password field, to drive [PasswordStrengthMeter].
  String _password = '';

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    // Dismiss the keyboard first, so a failure banner is not rendered behind
    // it on a phone.
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();

    final success = await ref.read(authNotifierProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: phone.isNotEmpty ? phone : null,
        );

    if (!mounted) return;

    if (success) {
      // Signals a *new* credential worth storing; paired with the
      // `newPassword` hint below, this is what makes a password manager offer
      // to save the account it just helped create.
      TextInput.finishAutofillContext();
      ModernToast.success(context, 'Pendaftaran berhasil! Selamat datang.');
      context.go(AppRoutes.dashboard);
    }
    // A failure stays on screen in the banner instead of a toast - see
    // [AuthErrorBanner].
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
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader.compact(),
              const SizedBox(height: AppDimensions.spacing32),
              const AuthFormTitle(
                title: 'Buat Akun Baru',
                subtitle: 'Isi data di bawah untuk mulai berjualan',
              ),
              const SizedBox(height: AppDimensions.spacing24),
              ModernTextField(
                label: 'Nama Lengkap',
                hint: 'Masukkan nama lengkap',
                controller: _fullNameController,
                focusNode: _fullNameFocus,
                leading: const Icon(Icons.person_outlined),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _emailFocus.requestFocus(),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                maxLength: 100,
                validator: Validators.fullName,
                enabled: !isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              ModernTextField(
                label: 'Email',
                hint: 'contoh@email.com',
                controller: _emailController,
                focusNode: _emailFocus,
                leading: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _phoneFocus.requestFocus(),
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
              ModernTextField(
                label: 'No. Telepon (opsional)',
                hint: '08xxxxxxxxxx',
                controller: _phoneController,
                focusNode: _phoneFocus,
                leading: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                autofillHints: const [AutofillHints.telephoneNumber],
                maxLength: 15,
                validator: Validators.phoneNumber,
                enabled: !isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              ModernPasswordField(
                label: 'Password',
                hint: 'Buat password yang kuat',
                controller: _passwordController,
                focusNode: _passwordFocus,
                leading: const Icon(Icons.lock_outlined),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                autofillHints: const [AutofillHints.newPassword],
                maxLength: 128,
                validator: Validators.password,
                enabled: !isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: _onPasswordChanged,
              ),
              // The requirements the validator will apply, shown while there
              // is still something to do about them. The hint text used to
              // carry them in one 63-character line that the field truncated.
              PasswordStrengthMeter(password: _password),
              const SizedBox(height: AppDimensions.spacing16),
              ModernPasswordField(
                label: 'Konfirmasi Password',
                hint: 'Ulangi password',
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocus,
                leading: const Icon(Icons.lock_outlined),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onRegister(),
                autofillHints: const [AutofillHints.newPassword],
                maxLength: 128,
                validator: _validateConfirmPassword,
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
                onPressed: isLoading ? null : _onRegister,
                isLoading: isLoading,
                size: ModernSize.large,
                fullWidth: true,
                child: const Text('Daftar'),
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
                    'Sudah punya akun? ',
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
      ),
    );
  }

  /// Rebuild for the strength meter - and, as a side effect, re-check the
  /// confirm field against the new password.
  ///
  /// The side effect is the whole reason this is a `setState` and not a plain
  /// assignment. Under `onUserInteraction` a field re-runs its validator on
  /// every rebuild *once the user has touched it*, so correcting the first
  /// password clears the "Password tidak cocok" still showing under the second
  /// one - which now matches - without the user having to touch it again.
  ///
  /// Two things look like shortcuts to the same effect and are not. Calling
  /// `_formKey.currentState.validate()` here validates *every* field, and
  /// setting `autovalidateMode` on the `Form` rather than on each field makes
  /// `FormState` do the same thing as soon as any one field is touched. Either
  /// way, typing the first character of a password lights up "Nama lengkap
  /// wajib diisi" and "Email wajib diisi" on two fields above it that the user
  /// has not reached yet. Hence the per-field modes on every field here.
  void _onPasswordChanged(String value) {
    setState(() => _password = value);
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }
    if (value != _passwordController.text) {
      return 'Password tidak cocok';
    }
    return null;
  }
}
