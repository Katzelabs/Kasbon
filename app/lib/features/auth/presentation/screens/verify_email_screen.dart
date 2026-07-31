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

/// Collects the 6-digit code emailed after sign-up.
///
/// A code rather than a tappable link: the app registers no deep-link handlers
/// on any platform, and an email link opened from a mobile mail client lands in
/// an in-app browser with no session. Typing six digits works identically on
/// Android, iOS, macOS and Chrome.
///
/// [email] arrives as a query parameter rather than as notifier state so that a
/// hard refresh on web - where this screen has a real URL - does not strand the
/// user on a form that no longer knows who it is verifying.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).verifyOtp(
          email: widget.email,
          token: _otpController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      // Not straight to the dashboard: verifying is what mints the first
      // session, so the router's onboarding gate has to get a look at this
      // user before anything decides where they belong.
      context.go(AppRoutes.splash);
    }
  }

  Future<bool> _onResend() async {
    final sent = await ref
        .read(authNotifierProvider.notifier)
        .resendOtp(email: widget.email);

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
        onPressed: isLoading ? null : () => context.go(AppRoutes.register),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader.compact(),
            const SizedBox(height: AppDimensions.spacing32),
            const AuthFormTitle(
              title: 'Verifikasi Email',
              subtitle: 'Kami mengirim kode 6 digit ke email Anda',
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
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onVerify(),
              // oneTimeCode is what lets iOS offer the code from the mail
              // notification, and Android autofill pull it from the message.
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              autofocus: true,
              validator: Validators.otp,
              enabled: !isLoading,
              // Per field, never on the Form - see the long note in
              // register_screen.dart on why that distinction matters.
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: AppDimensions.spacing24),
            AuthErrorBanner(
              message: authState.status == AuthStatus.error
                  ? authState.errorMessage
                  : null,
            ),
            ModernButton.primary(
              onPressed: isLoading ? null : _onVerify,
              isLoading: isLoading,
              size: ModernSize.large,
              fullWidth: true,
              child: const Text('Verifikasi'),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              'Tidak menerima kode? Periksa folder spam.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            OtpResendButton(
              onResend: _onResend,
              enabled: !isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
