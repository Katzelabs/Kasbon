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
import '../widgets/otp_resend_button.dart';
import '../widgets/password_strength_meter.dart';

/// Redeems a recovery code and sets a new password.
///
/// Both halves are one step deliberately. Verifying the code is what creates
/// the session the password change is made against, so splitting them across
/// two screens would leave a signed-in user on a screen they could walk away
/// from with their old password still live.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _otpFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  /// Mirrors the password field, to drive [PasswordStrengthMeter].
  String _password = '';

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).resetPassword(
          email: widget.email,
          token: _otpController.text.trim(),
          newPassword: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      TextInput.finishAutofillContext();
      ModernToast.success(context, 'Password berhasil diubah');
      // Redeeming the code already signed them in, so there is nothing to log
      // into. Hand off to the router, which knows whether this account still
      // owes an onboarding.
      context.go(AppRoutes.splash);
    }
  }

  Future<bool> _onResend() async {
    // There is no `resend` for recovery codes - asking for the reset again is
    // what issues a fresh one.
    final sent = await ref
        .read(authNotifierProvider.notifier)
        .requestPasswordReset(email: widget.email);

    if (mounted && sent) {
      ModernToast.success(context, 'Kode baru sudah dikirim');
    }
    return sent;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return AuthScaffold(
      leading: ModernIconButton(
        icon: Icons.arrow_back,
        onPressed:
            isLoading ? null : () => context.go(AppRoutes.forgotPassword),
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
                title: 'Password Baru',
                subtitle: 'Masukkan kode yang kami kirim, lalu buat password '
                    'baru',
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing24),
              ModernTextField(
                label: 'Kode Verifikasi',
                hint: '123456',
                controller: _otpController,
                focusNode: _otpFocus,
                leading: const Icon(Icons.lock_clock_outlined),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                autofocus: true,
                validator: Validators.otp,
                enabled: !isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              ModernPasswordField(
                label: 'Password Baru',
                hint: 'Minimal 8 karakter',
                controller: _passwordController,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                onChanged: _onPasswordChanged,
                autofillHints: const [AutofillHints.newPassword],
                maxLength: 128,
                validator: Validators.password,
                enabled: !isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              PasswordStrengthMeter(password: _password),
              const SizedBox(height: AppDimensions.spacing16),
              ModernPasswordField(
                label: 'Konfirmasi Password Baru',
                hint: 'Ulangi password',
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onSubmit(),
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
                onPressed: isLoading ? null : _onSubmit,
                isLoading: isLoading,
                size: ModernSize.large,
                fullWidth: true,
                child: const Text('Simpan Password Baru'),
              ),
              const SizedBox(height: AppDimensions.spacing16),
              OtpResendButton(
                onResend: _onResend,
                enabled: !isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// See the long note on the same method in `register_screen.dart`: the
  /// `setState` is what re-runs the confirm field's validator so a corrected
  /// first password clears the mismatch under the second.
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
