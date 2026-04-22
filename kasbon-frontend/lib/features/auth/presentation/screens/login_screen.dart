import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Login screen with email and password authentication.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      context.go('/dashboard');
    } else {
      final errorMessage = ref.read(authNotifierProvider).errorMessage;
      if (errorMessage != null) {
        ModernToast.error(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo / Branding
                    const Icon(
                      Icons.point_of_sale_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    Text(
                      'KASBON',
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacing4),
                    Text(
                      'Kasir Bisnis Online',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacing48),

                    // Title
                    const Text(
                      'Masuk ke Akun Anda',
                      style: AppTextStyles.h3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacing24),

                    // Email field
                    ModernTextField(
                      label: 'Email',
                      hint: 'contoh@email.com',
                      controller: _emailController,
                      leading: const Icon(Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      maxLength: 254,
                      validator: _validateEmail,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppDimensions.spacing16),

                    // Password field
                    ModernTextField(
                      label: 'Password',
                      hint: 'Masukkan password',
                      controller: _passwordController,
                      leading: const Icon(Icons.lock_outlined),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onLogin(),
                      maxLength: 128,
                      validator: _validatePassword,
                      enabled: !isLoading,
                      trailing: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                          size: AppDimensions.iconMedium,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing24),

                    // Login button
                    ModernButton.primary(
                      onPressed: isLoading ? null : _onLogin,
                      isLoading: isLoading,
                      size: ModernSize.large,
                      fullWidth: true,
                      child: const Text('Masuk'),
                    ),
                    const SizedBox(height: AppDimensions.spacing16),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun? ',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        ModernButton.text(
                          onPressed: isLoading
                              ? null
                              : () => context.push('/register'),
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
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    return Validators.email(value);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    return null;
  }
}
