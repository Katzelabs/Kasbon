import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled avatar for user/product images
///
/// Example:
/// ```dart
/// ModernAvatar(imageUrl: user.avatarUrl, initials: user.name[0])
/// ModernAvatar.initials('JD')
/// ModernAvatar.icon(Icons.person)
/// ```
class ModernAvatar extends StatelessWidget {
  const ModernAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.fallbackIcon = Icons.person,
    this.size = ModernSize.medium,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.badge,
    this.shape = ModernAvatarShape.circle,
    this.borderColor,
    this.borderWidth,
  });

  /// Creates an avatar with initials
  const ModernAvatar.initials(
    String text, {
    super.key,
    this.size = ModernSize.medium,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.badge,
    this.shape = ModernAvatarShape.circle,
    this.borderColor,
    this.borderWidth,
  })  : initials = text,
        imageUrl = null,
        fallbackIcon = Icons.person;

  /// Creates an avatar with an icon
  factory ModernAvatar.icon(
    IconData icon, {
    Key? key,
    ModernSize size = ModernSize.medium,
    Color? backgroundColor,
    Color? foregroundColor,
    VoidCallback? onTap,
    Widget? badge,
    ModernAvatarShape shape = ModernAvatarShape.circle,
    Color? borderColor,
    double? borderWidth,
  }) {
    return _IconAvatar(
      key: key,
      icon: icon,
      size: size,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      onTap: onTap,
      badge: badge,
      shape: shape,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }

  /// Creates a small avatar
  const ModernAvatar.small({
    super.key,
    this.imageUrl,
    this.initials,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.badge,
    this.shape = ModernAvatarShape.circle,
    this.borderColor,
    this.borderWidth,
  }) : size = ModernSize.small;

  /// Creates a medium avatar
  const ModernAvatar.medium({
    super.key,
    this.imageUrl,
    this.initials,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.badge,
    this.shape = ModernAvatarShape.circle,
    this.borderColor,
    this.borderWidth,
  }) : size = ModernSize.medium;

  /// Creates a large avatar
  const ModernAvatar.large({
    super.key,
    this.imageUrl,
    this.initials,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.badge,
    this.shape = ModernAvatarShape.circle,
    this.borderColor,
    this.borderWidth,
  }) : size = ModernSize.large;

  /// The image URL to display
  final String? imageUrl;

  /// The initials to display if no image
  final String? initials;

  /// The fallback icon if no image or initials
  final IconData fallbackIcon;

  /// The size of the avatar
  final ModernSize size;

  /// Custom background color
  final Color? backgroundColor;

  /// Custom foreground color (for initials/icon)
  final Color? foregroundColor;

  /// Callback when tapped
  final VoidCallback? onTap;

  /// Optional badge widget to overlay
  final Widget? badge;

  /// The shape of the avatar
  final ModernAvatarShape shape;

  /// Border color
  final Color? borderColor;

  /// Border width
  final double? borderWidth;

  double get _dimension {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.avatarSmall;
      case ModernSize.medium:
        return AppDimensions.avatarMedium;
      case ModernSize.large:
        return AppDimensions.avatarLarge;
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
        return AppTextStyles.labelSmall;
      case ModernSize.medium:
        return AppTextStyles.labelMedium;
      case ModernSize.large:
        return AppTextStyles.labelLarge;
    }
  }

  BorderRadius get _borderRadius {
    switch (shape) {
      case ModernAvatarShape.circle:
        return BorderRadius.circular(_dimension / 2);
      case ModernAvatarShape.rounded:
        return BorderRadius.circular(AppDimensions.radiusMedium);
      case ModernAvatarShape.square:
        return BorderRadius.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        backgroundColor ?? AppColors.primaryContainer;
    final effectiveForegroundColor = foregroundColor ?? AppColors.primary;

    Widget avatar = Container(
      width: _dimension,
      height: _dimension,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: _borderRadius,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth ?? 2)
            : null,
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {},
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: initials != null
                  ? Text(
                      initials!.substring(0, initials!.length.clamp(0, 2)).toUpperCase(),
                      style: _textStyle.copyWith(
                        color: effectiveForegroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Icon(
                      fallbackIcon,
                      size: _iconSize,
                      color: effectiveForegroundColor,
                    ),
            )
          : null,
    );

    if (badge != null) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: badge!,
          ),
        ],
      );
    }

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _borderRadius,
          child: avatar,
        ),
      );
    }

    return avatar;
  }
}

/// Internal widget for icon avatars
class _IconAvatar extends ModernAvatar {
  const _IconAvatar({
    super.key,
    required this.icon,
    super.size,
    super.backgroundColor,
    super.foregroundColor,
    super.onTap,
    super.badge,
    super.shape,
    super.borderColor,
    super.borderWidth,
  }) : super(fallbackIcon: icon);

  final IconData icon;
}

/// Avatar shapes
enum ModernAvatarShape {
  circle,
  rounded,
  square,
}

/// A group of avatars with overlap
class ModernAvatarGroup extends StatelessWidget {
  const ModernAvatarGroup({
    super.key,
    required this.avatars,
    this.maxVisible = 3,
    this.size = ModernSize.small,
    this.overlapFactor = 0.3,
    this.onTap,
  });

  /// The list of avatar data
  final List<ModernAvatarData> avatars;

  /// Maximum number of avatars to show
  final int maxVisible;

  /// The size of each avatar
  final ModernSize size;

  /// How much avatars overlap (0-1)
  final double overlapFactor;

  /// Callback when the group is tapped
  final VoidCallback? onTap;

  double get _dimension {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.avatarSmall;
      case ModernSize.medium:
        return AppDimensions.avatarMedium;
      case ModernSize.large:
        return AppDimensions.avatarLarge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = avatars.length.clamp(0, maxVisible);
    final extraCount = avatars.length - maxVisible;
    final overlap = _dimension * overlapFactor;

    Widget group = SizedBox(
      height: _dimension,
      width: _dimension + (visibleCount - 1) * (_dimension - overlap) +
          (extraCount > 0 ? (_dimension - overlap) : 0),
      child: Stack(
        children: [
          ...List.generate(visibleCount, (index) {
            final avatar = avatars[index];
            return Positioned(
              left: index * (_dimension - overlap),
              child: ModernAvatar(
                imageUrl: avatar.imageUrl,
                initials: avatar.initials,
                size: size,
                borderColor: AppColors.surface,
                borderWidth: 2,
              ),
            );
          }),
          if (extraCount > 0)
            Positioned(
              left: visibleCount * (_dimension - overlap),
              child: Container(
                width: _dimension,
                height: _dimension,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      group = GestureDetector(onTap: onTap, child: group);
    }

    return group;
  }
}

/// Data class for avatar group items
class ModernAvatarData {
  const ModernAvatarData({
    this.imageUrl,
    this.initials,
  });

  final String? imageUrl;
  final String? initials;
}
