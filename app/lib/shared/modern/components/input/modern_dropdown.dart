import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled dropdown field with consistent theming
///
/// Example:
/// ```dart
/// ModernDropdown<String>(
///   label: 'Satuan',
///   value: _selectedUnit,
///   items: _units.map((unit) => DropdownMenuItem(
///     value: unit,
///     child: Text(unit),
///   )).toList(),
///   onChanged: (value) => setState(() => _selectedUnit = value!),
/// )
/// ```
class ModernDropdown<T> extends StatelessWidget {
  const ModernDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.variant = ModernInputVariant.outline,
    this.leading,
    this.validator,
    this.enabled = true,
    this.isExpanded = true,
    this.focusNode,
  });

  /// The list of items to display in the dropdown
  final List<DropdownMenuItem<T>> items;

  /// Called when the user selects an item
  final void Function(T?) onChanged;

  /// The currently selected value
  final T? value;

  /// The label text displayed above the field
  final String? label;

  /// The hint text displayed when no value is selected
  final String? hint;

  /// Helper text displayed below the field
  final String? helperText;

  /// Error text displayed below the field (replaces helper when present)
  final String? errorText;

  /// The visual style variant
  final ModernInputVariant variant;

  /// Leading icon widget
  final Widget? leading;

  /// Validator function for form validation
  final String? Function(T?)? validator;

  /// Whether the dropdown is enabled
  final bool enabled;

  /// Whether the dropdown should expand to fill its parent
  final bool isExpanded;

  /// Focus node for keyboard navigation
  final FocusNode? focusNode;

  InputDecoration get _decoration {
    final hasError = errorText != null;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: leading,
      filled: variant == ModernInputVariant.filled,
      fillColor:
          variant == ModernInputVariant.filled ? AppColors.surfaceVariant : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
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

    switch (variant) {
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
    switch (variant) {
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
    // Using value parameter for controlled component pattern where parent manages state
    // ignore: deprecated_member_use
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: _decoration,
      validator: validator,
      isExpanded: isExpanded,
      focusNode: focusNode,
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: enabled ? AppColors.textSecondary : AppColors.textDisabled,
      ),
      dropdownColor: AppColors.surface,
      style: AppTextStyles.bodyMedium.copyWith(
        color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
      ),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    );
  }
}
