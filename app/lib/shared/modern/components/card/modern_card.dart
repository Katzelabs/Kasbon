import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_gradients.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../utils/modern_hover.dart';
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

  BoxBorder? _borderFor({required bool isHovered}) {
    if (variant != ModernCardVariant.outlined) return null;

    final base = borderColor ?? AppColors.border;

    // Deepen whatever border the card already has rather than replacing it.
    //
    // This was `borderColor ?? hoverTint`, which meant any caller supplying a
    // border - both product grid items, order_card, the table's narrow card,
    // all of them passing one unconditionally to show selection - silently got
    // no hover at all. Darkening in HSL keeps a selected card's accent hue
    // while still reacting to the pointer.
    final hovered = HSLColor.fromColor(base);

    return Border.all(
      color: isHovered
          ? hovered
              .withLightness((hovered.lightness - 0.15).clamp(0.0, 1.0))
              .toColor()
          : base,
      width: 1,
    );
  }

  /// Maps the numeric [elevation] onto the semantic shadow ramp.
  ///
  /// The previous formula - `blurRadius: elevation * 2` at 10% black - gave a
  /// 4px-blur contact shadow with no ambient layer, which is what made cards
  /// look stamped onto the page rather than resting above it.
  List<BoxShadow>? _shadowFor({required bool isHovered}) {
    // Resting elevation is unchanged: a flat variant still has no shadow until
    // a pointer is on it.
    final resting = variant.hasElevation ? _elevation : 0.0;

    // The lift is what a card grid can actually show. The first attempt bumped
    // the elevation *after* an `if (!variant.hasElevation) return null`, so
    // outlined and filled cards - which is nearly every card in the app -
    // never lifted, and their only hover cue was a 1px border going from
    // #E5E7EB to a slightly darker grey. Invisible at arm's length, which is
    // exactly how it was reported.
    //
    // Three steps rather than two so the outlined case clears the ramp's first
    // rung and lands on a shadow you can see.
    final e = resting + (isHovered ? 3 : 0);
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

    final isInteractive = onTap != null || onLongPress != null;

    // The ink surface goes *inside* the decorated box, not around it.
    //
    // An InkWell does not paint its own splash - the enclosing Material does,
    // beneath its child. With the Material wrapped around the card, the card's
    // own opaque background painted straight over the ripple, so a tap looked
    // like nothing at all. Nesting it here means the background paints first,
    // the ink over it, and the content over that.
    //
    // The container's clipBehavior then keeps the splash inside the rounded
    // corners, which is why this does not need its own ClipRRect.
    Widget surface(bool isHovered) {
      if (!isInteractive) return content;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: effectiveBorderRadius,
          child: content,
        ),
      );
    }

    // The border paints *over* the content, not under it.
    //
    // A Container clips its child to the outer rounded rect - the same path the
    // border's outer edge follows - and paints its decoration underneath. So a
    // child that fills the card, like a product photo bleeding to the top edge,
    // painted straight over the 1px border. Along a straight edge that only
    // costs a pixel; at the corners the child's antialiased curve and the
    // border's antialiased curve are drawn one over the other, and the border
    // dissolves into a ragged notch - which is exactly what the grid's top two
    // corners looked like once a selected or hovered card coloured that border.
    //
    // As a foreground decoration it is drawn after the child and after the ink
    // splash, so all four corners close whatever the card contains.
    Widget buildCard(bool isHovered) {
      final border = _borderFor(isHovered: isHovered);

      return AnimatedContainer(
        duration: ModernHoverBuilder.duration,
        curve: Curves.easeOut,
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: effectiveBorderRadius,
          boxShadow: _shadowFor(isHovered: isHovered),
        ),
        foregroundDecoration: border == null
            ? null
            : BoxDecoration(
                borderRadius: effectiveBorderRadius,
                border: border,
              ),
        clipBehavior: clipBehavior,
        child: surface(isHovered),
      );
    }

    if (!isInteractive) return buildCard(false);

    // InkWell already sets a click cursor and paints a hover overlay. What it
    // cannot do is change the card's own elevation or border, which is the
    // part a desktop user actually reads at a glance across a grid.
    return ModernHoverBuilder(
      builder: (context, isHovered, _) => buildCard(isHovered),
    );
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

    // Same nesting as ModernCard, and for the same reason: a gradient is as
    // opaque as a solid fill, so a Material wrapped around this card hid every
    // ripple the dashboard's summary cards ever tried to show.
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: content,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: effectiveBorderRadius,
        boxShadow: AppShadows.glow(glowSource, opacity: 0.24),
      ),
      // Needed now that the ink lives inside: without it the splash paints
      // square corners over the gradient's rounded ones.
      clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
      child: content,
    );
  }
}
