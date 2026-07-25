import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled text field with consistent theming
///
/// Example:
/// ```dart
/// ModernTextField(
///   label: 'Email',
///   hint: 'Masukkan email',
///   controller: _emailController,
/// )
/// ModernTextField.password(
///   label: 'Password',
///   controller: _passwordController,
/// )
/// ```
class ModernTextField extends StatefulWidget {
  const ModernTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.variant = ModernInputVariant.outline,
    this.size = ModernSize.medium,
    this.leading,
    this.trailing,
    this.onTrailingTap,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.initialValue,
  });

  /// Creates a password text field with visibility toggle
  ///
  /// Use [ModernPasswordField] widget directly for a stateful password field
  /// with visibility toggle.
  const ModernTextField.password({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.variant = ModernInputVariant.outline,
    this.size = ModernSize.medium,
    this.leading,
    this.trailing,
    this.onTrailingTap,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.initialValue,
  })  : obscureText = true,
        maxLines = 1,
        minLines = null,
        maxLength = null,
        keyboardType = TextInputType.visiblePassword,
        textCapitalization = TextCapitalization.none,
        inputFormatters = null,
        readOnly = false;

  /// Creates a multiline text field
  factory ModernTextField.multiline({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hint,
    String? helperText,
    String? errorText,
    ModernInputVariant variant = ModernInputVariant.outline,
    int maxLines = 4,
    int? minLines,
    int? maxLength,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
    bool autofocus = false,
    FocusNode? focusNode,
  }) {
    return ModernTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      errorText: errorText,
      variant: variant,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      keyboardType: TextInputType.multiline,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
    );
  }

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final ModernInputVariant variant;
  final ModernSize size;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? initialValue;

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  InputDecoration get _decoration {
    final hasError = widget.errorText != null;

    return InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: widget.leading,
      suffixIcon: widget.trailing != null
          ? widget.onTrailingTap != null
              ? IconButton(
                  icon: widget.trailing!,
                  onPressed: widget.onTrailingTap,
                )
              : widget.trailing
          : null,
      filled: widget.variant == ModernInputVariant.filled,
      fillColor: widget.variant == ModernInputVariant.filled
          ? AppColors.surfaceVariant
          : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: widget.maxLines == 1
            ? AppDimensions.spacing12
            : AppDimensions.spacing16,
      ),
      border: _getBorder(hasError: false, focused: false),
      enabledBorder: _getBorder(hasError: false, focused: false),
      focusedBorder: _getBorder(hasError: false, focused: true),
      errorBorder: _getBorder(hasError: true, focused: false),
      focusedErrorBorder: _getBorder(hasError: true, focused: true),
      disabledBorder: _getDisabledBorder(),
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: hasError ? AppColors.error : AppColors.textSecondary,
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textTertiary,
      ),
      helperStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
      ),
      errorStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.error,
      ),
    );
  }

  InputBorder _getBorder({required bool hasError, required bool focused}) {
    final color = hasError
        ? AppColors.error
        : focused
            ? AppColors.primary
            : AppColors.border;
    final width = focused ? 2.0 : 1.0;

    switch (widget.variant) {
      case ModernInputVariant.outline:
      case ModernInputVariant.filled:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: color, width: width),
        );
      case ModernInputVariant.underline:
        return UnderlineInputBorder(
          borderSide: BorderSide(color: color, width: width),
        );
    }
  }

  InputBorder _getDisabledBorder() {
    switch (widget.variant) {
      case ModernInputVariant.outline:
      case ModernInputVariant.filled:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        );
      case ModernInputVariant.underline:
        return const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      decoration: _decoration,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      style: AppTextStyles.bodyMedium.copyWith(
        color: widget.enabled ? AppColors.textPrimary : AppColors.textDisabled,
      ),
    );
  }
}

/// Password field with visibility toggle
///
/// A stateful password field that provides a built-in visibility toggle button.
///
/// Example:
/// ```dart
/// ModernPasswordField(
///   label: 'Password',
///   hint: 'Masukkan password',
///   controller: _passwordController,
/// )
/// ```
class ModernPasswordField extends StatefulWidget {
  const ModernPasswordField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.variant = ModernInputVariant.outline,
    this.size = ModernSize.medium,
    this.leading,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final ModernInputVariant variant;
  final ModernSize size;
  final Widget? leading;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<ModernPasswordField> createState() => _ModernPasswordFieldState();
}

class _ModernPasswordFieldState extends State<ModernPasswordField> {
  bool _obscureText = true;

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModernTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      variant: widget.variant,
      size: widget.size,
      leading: widget.leading,
      trailing: Icon(
        _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.textSecondary,
      ),
      onTrailingTap: _toggleVisibility,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
    );
  }
}
