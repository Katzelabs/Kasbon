import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../../../../config/routes/app_router.dart';

/// Registration screen for new user accounts.
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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
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
      ModernToast.success(context, 'Pendaftaran berhasil! Selamat datang.');
      context.go(AppRoutes.dashboard);
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
              vertical: AppDimensions.spacing24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ModernIconButton(
                        icon: Icons.arrow_back,
                        onPressed: isLoading
                            ? null
                            : () => context.go(AppRoutes.login),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing16),

                    // Header
                    const Text(
                      'Buat Akun Baru',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacing4),
                    Text(
                      'Isi data di bawah untuk mendaftar',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacing32),

                    // Full name
                    ModernTextField(
                      label: 'Nama Lengkap',
                      hint: 'Masukkan nama lengkap',
                      controller: _fullNameController,
                      leading: const Icon(Icons.person_outlined),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      validator: _validateFullName,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppDimensions.spacing16),

                    // Email
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

                    // Phone (optional)
                    ModernTextField(
                      label: 'No. Telepon (opsional)',
                      hint: '08xxxxxxxxxx',
                      controller: _phoneController,
                      leading: const Icon(Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 15,
                      validator: _validatePhone,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppDimensions.spacing16),

                    // Password
                    ModernTextField(
                      label: 'Password',
                      hint:
                          'Minimal 8 karakter dengan huruf besar, kecil, dan angka',
                      controller: _passwordController,
                      leading: const Icon(Icons.lock_outlined),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: AppDimensions.spacing16),

                    // Confirm password
                    ModernTextField(
                      label: 'Konfirmasi Password',
                      hint: 'Ulangi password',
                      controller: _confirmPasswordController,
                      leading: const Icon(Icons.lock_outlined),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onRegister(),
                      maxLength: 128,
                      validator: _validateConfirmPassword,
                      enabled: !isLoading,
                      trailing: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                          size: AppDimensions.iconMedium,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirmPassword =
                              !_obscureConfirmPassword);
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing24),

                    // Register button
                    ModernButton.primary(
                      onPressed: isLoading ? null : _onRegister,
                      isLoading: isLoading,
                      size: ModernSize.large,
                      fullWidth: true,
                      child: const Text('Daftar'),
                    ),
                    const SizedBox(height: AppDimensions.spacing16),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sudah punya akun? ',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        ModernButton.text(
                          onPressed: isLoading
                              ? null
                              : () => context.go(AppRoutes.login),
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
          ),
        ),
      ),
    );
  }

  String? _validateFullName(String? value) {
    return Validators.fullName(value);
  }

  String? _validateEmail(String? value) {
    return Validators.email(value);
  }

  String? _validatePhone(String? value) {
    return Validators.phoneNumber(value);
  }

  String? _validatePassword(String? value) {
    return Validators.password(value);
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
