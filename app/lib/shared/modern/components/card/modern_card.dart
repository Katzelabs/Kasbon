import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_gradients.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled card with consistent theming and multiple variants
///
/// Example:
/// ```dart
/// ModernCard(child: Text('Content'))
/// ModernCard.elevated(child: ListTile(...))
/// ModernCard.outlined(onTap: _onTap, child: ProductInfo())
/// ```
class ModernCard extends StatelessWidget {
  const ModernCard({
    super.key,
    required this.child,
    this.variant = ModernCardVariant.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.elevation,
    this.color,
    this.borderColor,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  /// Creates an elevated card with shadow
  const ModernCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.elevation,
    this.color,
    this.borderColor,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = ModernCardVariant.elevated;

  /// Creates an outlined card with border
  const ModernCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.elevation,
    this.color,
    this.borderColor,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = ModernCardVariant.outlined;

  /// Creates a filled card with background color
  const ModernCard.filled({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.elevation,
    this.color,
    this.borderColor,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = ModernCardVariant.filled;

  /// The card's content
  final Widget child;

  /// The visual style variant
  final ModernCardVariant variant;

  /// Padding inside the card
  final EdgeInsets? padding;

  /// Margin around the card
  final EdgeInsets? margin;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Callback when card is long pressed
  final VoidCallback? onLongPress;

  /// Custom border radius
  final BorderRadius? borderRadius;

  /// Custom elevation (for elevated variant)
  final double? elevation;

  /// Custom background color
  final Color? color;

  /// Custom border color (for outlined variant)
  final Color? borderColor;

  /// Fixed width
  final double? width;

  /// Fixed height
  final double? height;

  /// Clip behavior
  final Clip clipBehavior;

  Color get _backgroundColor {
    if (color != null) return color!;
    switch (variant) {
      case ModernCardVariant.elevated:
        return AppColors.card;
      case ModernCardVariant.outlined:
        return AppColors.surface;
      case ModernCardVariant.filled:
        return AppColors.surfaceVariant;
    }
  }

  double get _elevation {
    if (elevation != null) return elevation!;
    switch (variant) {
      case ModernCardVariant.elevated:
        return 2;
      case ModernCardVariant.outlined:
      case ModernCardVariant.filled:
        return 0;
    }
  }

  BoxBorder? get _border {
    if (variant == ModernCardVariant.outlined) {
      return Border.all(
        color: borderColor ?? AppColors.border,
        width: 1,
      );
    }
    return null;
  }

  /// Maps the numeric [elevation] onto the semantic shadow ramp.
  ///
  /// The previous formula - `blurRadius: elevation * 2` at 10% black - gave a
  /// 4px-blur contact shadow with no ambient layer, which is what made cards
  /// look stamped onto the page rather than resting above it.
  List<BoxShadow>? get _shadow {
    if (!variant.hasElevation) return null;
    final e = _elevation;
    if (e <= 0) return null;
    if (e <= 1) return AppShadows.xs;
    if (e <= 2) return AppShadows.sm;
    if (e <= 4) return AppShadows.md;
    if (e <= 8) return AppShadows.lg;
    return AppShadows.xl;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusLarge);

    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: effectiveBorderRadius,
        border: _border,
        boxShadow: _shadow,
      ),
      clipBehavior: clipBehavior,
      child: content,
    );

    if (onTap != null || onLongPress != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: effectiveBorderRadius,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// A gradient card for dashboard summaries
class ModernGradientCard extends StatelessWidget {
  const ModernGradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.width,
    this.height,
  });

  /// Creates a primary gradient card
  factory ModernGradientCard.primary({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
    double? width,
    double? height,
  }) {
    return ModernGradientCard(
      key: key,
      gradient: AppGradients.primaryCard,
      padding: padding,
      margin: margin,
      onTap: onTap,
      borderRadius: borderRadius,
      width: width,
      height: height,
      child: child,
    );
  }

  /// Creates a success gradient card
  factory ModernGradientCard.success({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
    double? width,
    double? height,
  }) {
    return ModernGradientCard(
      key: key,
      gradient: AppGradients.successCard,
      padding: padding,
      margin: margin,
      onTap: onTap,
      borderRadius: borderRadius,
      width: width,
      height: height,
      child: child,
    );
  }

  /// Creates a warning gradient card
  factory ModernGradientCard.warning({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
    double? width,
    double? height,
  }) {
    return ModernGradientCard(
      key: key,
      gradient: AppGradients.warningCard,
      padding: padding,
      margin: margin,
      onTap: onTap,
      borderRadius: borderRadius,
      width: width,
      height: height,
      child: child,
    );
  }

  /// Creates an error gradient card
  factory ModernGradientCard.error({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
    double? width,
    double? height,
  }) {
    return ModernGradientCard(
      key: key,
      gradient: AppGradients.errorCard,
      padding: padding,
      margin: margin,
      onTap: onTap,
      borderRadius: borderRadius,
      width: width,
      height: height,
      child: child,
    );
  }

  /// The card's content
  final Widget child;

  /// The gradient background
  final Gradient? gradient;

  /// Padding inside the card
  final EdgeInsets? padding;

  /// Margin around the card
  final EdgeInsets? margin;

  /// Callback when tapped
  final VoidCallback? onTap;

  /// Custom border radius
  final BorderRadius? borderRadius;

  /// Fixed width
  final double? width;

  /// Fixed height
  final double? height;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusLarge);

    final effectiveGradient = gradient ?? AppGradients.primaryCard;

    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    // Tint the shadow with the card's own hue. A neutral grey shadow beneath a
    // saturated surface desaturates its edge and reads as grime.
    final glowSource = effectiveGradient is LinearGradient
        ? effectiveGradient.colors.first
        : AppColors.primary;

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: effectiveBorderRadius,
        boxShadow: AppShadows.glow(glowSource, opacity: 0.24),
      ),
      child: content,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: card,
        ),
      );
    }

    return card;
  }
}
