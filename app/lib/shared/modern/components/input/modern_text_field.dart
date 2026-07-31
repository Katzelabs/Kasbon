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
    this.autofillHints,
    this.showCounter = false,
    this.autovalidateMode,
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
    this.autofillHints,
    this.autovalidateMode,
  })  : obscureText = true,
        maxLines = 1,
        minLines = null,
        maxLength = null,
        keyboardType = TextInputType.visiblePassword,
        textCapitalization = TextCapitalization.none,
        inputFormatters = null,
        readOnly = false,
        showCounter = false;

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
    bool showCounter = false,
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
      showCounter: showCounter,
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

  /// What the platform's autofill service should offer for this field.
  ///
  /// Without this a password manager has nothing to match on, so it silently
  /// offers nothing - the failure looks like the OS not supporting autofill
  /// rather than like a missing parameter. Wrap the fields of one credential
  /// in an `AutofillGroup` so they are saved together.
  final Iterable<String>? autofillHints;

  /// Whether to show the `12/128` character counter [maxLength] adds.
  ///
  /// Off by default, because [maxLength] is almost always used here as an
  /// input *cap* - a defensive bound on what reaches the database - and not as
  /// a budget the user is meant to spend. Every auth field carried one of
  /// these counters purely as a side effect of being bounded. Turn it on for
  /// the rare field where the remaining count is genuinely useful, such as a
  /// multiline note.
  final bool showCounter;

  /// When this field re-runs its [validator].
  ///
  /// Null leaves it to the enclosing `Form`, which is the historical behaviour
  /// and means "only when something calls `validate()`".
  ///
  /// Prefer setting [AutovalidateMode.onUserInteraction] *here*, per field,
  /// over setting it on the `Form`. They sound equivalent and are not:
  /// `FormState` re-validates **every** field as soon as **any** field has
  /// been touched, so typing the first character of a password decorates the
  /// two fields below it with "wajib diisi" before the user has reached them.
  /// Set on the field, it does what the name suggests - this field validates
  /// once this field has been used.
  final AutovalidateMode? autovalidateMode;

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
      autofillHints: widget.autofillHints,
      autovalidateMode: widget.autovalidateMode,
      // `buildCounter` returning null is what suppresses the counter; leaving
      // it unset is what renders one. See [ModernTextField.showCounter].
      buildCounter: widget.showCounter
          ? null
          : (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) =>
              null,
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
    this.autofillHints,
    this.maxLength,
    this.autovalidateMode,
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

  /// Usually `[AutofillHints.password]` to sign in, or
  /// `[AutofillHints.newPassword]` to register - the second is what prompts a
  /// password manager to *generate* and then save one.
  final Iterable<String>? autofillHints;

  /// Defensive cap on the stored value. Never shows a counter.
  final int? maxLength;

  /// See [ModernTextField.autovalidateMode] - including why this belongs on
  /// the field rather than on the enclosing `Form`.
  final AutovalidateMode? autovalidateMode;

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
      // Semantics, not decoration: an icon that flips between two eyes is
      // meaningless to a screen reader without a label saying which way it
      // will flip.
      trailing: Semantics(
        button: true,
        label: _obscureText ? 'Tampilkan password' : 'Sembunyikan password',
        child: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.textSecondary,
          size: AppDimensions.iconMedium,
        ),
      ),
      onTrailingTap: widget.enabled ? _toggleVisibility : null,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      maxLength: widget.maxLength,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      autofillHints: widget.autofillHints,
      autovalidateMode: widget.autovalidateMode,
    );
  }
}
