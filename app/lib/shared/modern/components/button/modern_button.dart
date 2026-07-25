import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';
import '../feedback/modern_loading.dart';

/// A Modern-styled button with consistent theming and multiple variants
///
/// Example:
/// ```dart
/// ModernButton(child: Text('Submit'), onPressed: _onSubmit)
/// ModernButton.primary(child: Text('Save'), onPressed: _onSave)
/// ModernButton.outline(child: Text('Cancel'), onPressed: _onCancel)
/// ModernButton.destructive(child: Text('Delete'), onPressed: _onDelete)
/// ```
class ModernButton extends StatelessWidget {
  const ModernButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = ModernButtonVariant.primary,
    this.size = ModernSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.hapticFeedback = true,
    this.borderRadius,
  });

  /// Creates a button with just a label text
  factory ModernButton.label({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    ModernButtonVariant variant = ModernButtonVariant.primary,
    ModernSize size = ModernSize.medium,
    IconData? leadingIcon,
    IconData? trailingIcon,
    bool isLoading = false,
    bool fullWidth = false,
    bool hapticFeedback = true,
  }) {
    return ModernButton(
      key: key,
      onPressed: onPressed,
      variant: variant,
      size: size,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      isLoading: isLoading,
      fullWidth: fullWidth,
      hapticFeedback: hapticFeedback,
      child: Text(label),
    );
  }

  /// Creates a primary (filled) button
  const ModernButton.primary({
    super.key,
    required this.child,
    this.onPressed,
    this.size = ModernSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.hapticFeedback = true,
    this.borderRadius,
  }) : variant = ModernButtonVariant.primary;

  /// Creates a secondary button
  const ModernButton.secondary({
    super.key,
    required this.child,
    this.onPressed,
    this.size = ModernSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.hapticFeedback = true,
    this.borderRadius,
  }) : variant = ModernButtonVariant.secondary;

  /// Creates an outlined button
  const ModernButton.outline({
    super.key,
    required this.child,
    this.onPressed,
    this.size = ModernSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.hapticFeedback = true,
    this.borderRadius,
  }) : variant = ModernButtonVariant.outline;

  /// Creates a text button
  const ModernButton.text({
    super.key,
    required this.child,
    this.onPressed,
    this.size = ModernSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.hapticFeedback = true,
    this.borderRadius,
  }) : variant = ModernButtonVariant.text;

  /// Creates a destructive/danger button
  const ModernButton.destructive({
    super.key,
    required this.child,
    this.onPressed,
    this.size = ModernSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.hapticFeedback = true,
    this.borderRadius,
  }) : variant = ModernButtonVariant.destructive;

  /// The button's child widget (usually Text)
  final Widget child;

  /// Callback when the button is pressed
  final VoidCallback? onPressed;

  /// The visual style variant
  final ModernButtonVariant variant;

  /// The size of the button
  final ModernSize size;

  /// Optional leading icon
  final IconData? leadingIcon;

  /// Optional trailing icon
  final IconData? trailingIcon;

  /// Whether to show a loading indicator
  final bool isLoading;

  /// Whether the button should take full width
  final bool fullWidth;

  /// Whether to provide haptic feedback on press
  final bool hapticFeedback;

  /// Custom border radius (overrides default)
  final BorderRadius? borderRadius;

  bool get _isDisabled => onPressed == null || isLoading;

  double get _height {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.buttonHeightSmall;
      case ModernSize.medium:
        return AppDimensions.buttonHeightMedium;
      case ModernSize.large:
        return AppDimensions.buttonHeightLarge;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case ModernSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing12,
          vertical: AppDimensions.spacing4,
        );
      case ModernSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing8,
        );
      case ModernSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
          vertical: AppDimensions.spacing12,
        );
    }
  }

  double get _iconSize {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.iconSmall;
      case ModernSize.medium:
        return AppDimensions.iconMedium;
      case ModernSize.large:
        return AppDimensions.iconLarge;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case ModernSize.small:
        return AppTextStyles.buttonSmall;
      case ModernSize.medium:
      case ModernSize.large:
        return AppTextStyles.button;
    }
  }

  Color get _backgroundColor {
    if (_isDisabled) {
      return variant.isFilled ? AppColors.primaryDisabled : Colors.transparent;
    }
    switch (variant) {
      case ModernButtonVariant.primary:
        return AppColors.primary;
      case ModernButtonVariant.secondary:
        return AppColors.primaryContainer;
      case ModernButtonVariant.destructive:
        return AppColors.error;
      case ModernButtonVariant.outline:
      case ModernButtonVariant.text:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    if (_isDisabled) {
      return variant.isFilled ? AppColors.onPrimary : AppColors.textDisabled;
    }
    switch (variant) {
      case ModernButtonVariant.primary:
        return AppColors.onPrimary;
      case ModernButtonVariant.secondary:
        return AppColors.primary;
      case ModernButtonVariant.destructive:
        return Colors.white;
      case ModernButtonVariant.outline:
        return AppColors.primary;
      case ModernButtonVariant.text:
        return AppColors.primary;
    }
  }

  BorderSide? get _border {
    if (variant == ModernButtonVariant.outline) {
      return BorderSide(
        color: _isDisabled ? AppColors.border : AppColors.primary,
        width: 1.5,
      );
    }
    return null;
  }

  void _handleTap() {
    if (hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveChild = DefaultTextStyle.merge(
      style: _textStyle.copyWith(color: _foregroundColor),
      child: child,
    );

    final buttonContent = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          ModernLoading.small(color: _foregroundColor),
          const SizedBox(width: AppDimensions.spacing8),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: _iconSize, color: _foregroundColor),
          const SizedBox(width: AppDimensions.spacing8),
        ],
        effectiveChild,
        if (trailingIcon != null && !isLoading) ...[
          const SizedBox(width: AppDimensions.spacing8),
          Icon(trailingIcon, size: _iconSize, color: _foregroundColor),
        ],
      ],
    );

    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusMedium);

    final button = Container(
      height: _height,
      padding: _padding,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: effectiveBorderRadius,
        border: _border != null ? Border.fromBorderSide(_border!) : null,
      ),
      child: buttonContent,
    );

    Widget result = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isDisabled ? null : _handleTap,
        borderRadius: effectiveBorderRadius,
        child: button,
      ),
    );

    if (fullWidth) {
      result = SizedBox(width: double.infinity, child: result);
    }

    return result;
  }
}
