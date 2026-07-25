import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../utils/modern_variants.dart';

/// Icon button variant for ModernIconButton
enum ModernIconButtonVariant {
  /// Filled background with icon
  filled,

  /// Tonal/light background with icon
  tonal,

  /// Outlined with border
  outlined,

  /// Ghost/standard with no background
  standard;
}

/// A Modern-styled icon button with consistent theming
///
/// Example:
/// ```dart
/// ModernIconButton(icon: Icons.add, onPressed: _onAdd)
/// ModernIconButton.filled(icon: Icons.edit, onPressed: _onEdit)
/// ModernIconButton.outlined(icon: Icons.delete, color: AppColors.error)
/// ```
class ModernIconButton extends StatelessWidget {
  const ModernIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = ModernIconButtonVariant.standard,
    this.size = ModernSize.medium,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.hapticFeedback = true,
  });

  /// Creates a filled icon button
  const ModernIconButton.filled({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = ModernSize.medium,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.hapticFeedback = true,
  }) : variant = ModernIconButtonVariant.filled;

  /// Creates a tonal (light background) icon button
  const ModernIconButton.tonal({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = ModernSize.medium,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.hapticFeedback = true,
  }) : variant = ModernIconButtonVariant.tonal;

  /// Creates an outlined icon button
  const ModernIconButton.outlined({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = ModernSize.medium,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.hapticFeedback = true,
  }) : variant = ModernIconButtonVariant.outlined;

  /// Creates a standard/ghost icon button (no background)
  const ModernIconButton.standard({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = ModernSize.medium,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.hapticFeedback = true,
  }) : variant = ModernIconButtonVariant.standard;

  /// The icon to display
  final IconData icon;

  /// Callback when the button is pressed
  final VoidCallback? onPressed;

  /// The visual style variant
  final ModernIconButtonVariant variant;

  /// The size of the button
  final ModernSize size;

  /// Custom icon color (overrides default)
  final Color? color;

  /// Custom background color (overrides default)
  final Color? backgroundColor;

  /// Optional tooltip text
  final String? tooltip;

  /// Whether to provide haptic feedback
  final bool hapticFeedback;

  bool get _isDisabled => onPressed == null;

  double get _dimension {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.buttonHeightSmall;
      case ModernSize.medium:
        return AppDimensions.buttonHeightMedium;
      case ModernSize.large:
        return AppDimensions.buttonHeightLarge;
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

  Color get _backgroundColor {
    if (backgroundColor != null) return backgroundColor!;
    if (_isDisabled) {
      switch (variant) {
        case ModernIconButtonVariant.filled:
          return AppColors.primaryDisabled;
        case ModernIconButtonVariant.tonal:
          return AppColors.surfaceVariant;
        case ModernIconButtonVariant.outlined:
        case ModernIconButtonVariant.standard:
          return Colors.transparent;
      }
    }
    switch (variant) {
      case ModernIconButtonVariant.filled:
        return AppColors.primary;
      case ModernIconButtonVariant.tonal:
        return AppColors.primaryContainer;
      case ModernIconButtonVariant.outlined:
      case ModernIconButtonVariant.standard:
        return Colors.transparent;
    }
  }

  Color get _iconColor {
    if (color != null) return _isDisabled ? color!.withValues(alpha: 0.5) : color!;
    if (_isDisabled) return AppColors.textDisabled;
    switch (variant) {
      case ModernIconButtonVariant.filled:
        return AppColors.onPrimary;
      case ModernIconButtonVariant.tonal:
      case ModernIconButtonVariant.outlined:
      case ModernIconButtonVariant.standard:
        return AppColors.primary;
    }
  }

  BoxBorder? get _border {
    if (variant == ModernIconButtonVariant.outlined) {
      return Border.all(
        color: _isDisabled ? AppColors.border : (color ?? AppColors.primary),
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
    Widget button = Container(
      width: _dimension,
      height: _dimension,
      decoration: BoxDecoration(
        color: _backgroundColor,
        shape: BoxShape.circle,
        border: _border,
      ),
      child: Center(
        child: Icon(icon, size: _iconSize, color: _iconColor),
      ),
    );

    button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isDisabled ? null : _handleTap,
        borderRadius: BorderRadius.circular(_dimension / 2),
        child: button,
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
