import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
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

  List<BoxShadow>? get _shadow {
    if (!variant.hasElevation || _elevation == 0) return null;
    return [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: _elevation * 2,
        offset: Offset(0, _elevation),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusMedium);

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
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
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
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.success, Color(0xFF059669)],
      ),
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
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.warning, Color(0xFFD97706)],
      ),
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
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.error, Color(0xFFDC2626)],
      ),
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
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusMedium);

    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
        borderRadius: effectiveBorderRadius,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
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
