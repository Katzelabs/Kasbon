import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled badge for status indicators
///
/// Example:
/// ```dart
/// ModernBadge(label: 'Aktif', variant: ModernBadgeVariant.success)
/// ModernBadge.success(label: 'Lunas')
/// ModernBadge.error(label: 'Hutang')
/// ```
class ModernBadge extends StatelessWidget {
  const ModernBadge({
    super.key,
    required this.label,
    this.variant = ModernBadgeVariant.neutral,
    this.icon,
    this.showDot = false,
    this.size = ModernSize.medium,
  });

  /// Creates a success badge
  const ModernBadge.success({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
    this.size = ModernSize.medium,
  }) : variant = ModernBadgeVariant.success;

  /// Creates a warning badge
  const ModernBadge.warning({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
    this.size = ModernSize.medium,
  }) : variant = ModernBadgeVariant.warning;

  /// Creates an error badge
  const ModernBadge.error({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
    this.size = ModernSize.medium,
  }) : variant = ModernBadgeVariant.error;

  /// Creates an info badge
  const ModernBadge.info({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
    this.size = ModernSize.medium,
  }) : variant = ModernBadgeVariant.info;

  /// Creates a neutral badge
  const ModernBadge.neutral({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
    this.size = ModernSize.medium,
  }) : variant = ModernBadgeVariant.neutral;

  /// The badge label text
  final String label;

  /// The visual style variant
  final ModernBadgeVariant variant;

  /// Optional leading icon
  final IconData? icon;

  /// Whether to show a dot indicator
  final bool showDot;

  /// The size of the badge
  final ModernSize size;

  Color get _backgroundColor {
    switch (variant) {
      case ModernBadgeVariant.success:
        return AppColors.successLight;
      case ModernBadgeVariant.warning:
        return AppColors.warningLight;
      case ModernBadgeVariant.error:
        return AppColors.errorLight;
      case ModernBadgeVariant.info:
        return AppColors.infoLight;
      case ModernBadgeVariant.neutral:
        return AppColors.surfaceVariant;
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case ModernBadgeVariant.success:
        return AppColors.success;
      case ModernBadgeVariant.warning:
        return AppColors.warning;
      case ModernBadgeVariant.error:
        return AppColors.error;
      case ModernBadgeVariant.info:
        return AppColors.info;
      case ModernBadgeVariant.neutral:
        return AppColors.textSecondary;
    }
  }

  double get _height {
    switch (size) {
      case ModernSize.small:
        return 20;
      case ModernSize.medium:
        return AppDimensions.badgeHeight;
      case ModernSize.large:
        return 28;
    }
  }

  double get _iconSize {
    switch (size) {
      case ModernSize.small:
        return 12;
      case ModernSize.medium:
        return 14;
      case ModernSize.large:
        return 16;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      padding: EdgeInsets.symmetric(
        horizontal: size == ModernSize.small
            ? AppDimensions.spacing4
            : AppDimensions.badgePaddingHorizontal,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _foregroundColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing4),
          ],
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: _foregroundColor),
            const SizedBox(width: AppDimensions.spacing4),
          ],
          Text(
            label,
            style: _textStyle.copyWith(color: _foregroundColor),
          ),
        ],
      ),
    );
  }
}

/// A counter badge for showing counts (e.g., cart items)
class ModernCounterBadge extends StatelessWidget {
  const ModernCounterBadge({
    super.key,
    required this.count,
    this.showZero = false,
    this.maxCount = 99,
    this.variant = ModernBadgeVariant.error,
  });

  /// The count to display
  final int count;

  /// Whether to show the badge when count is 0
  final bool showZero;

  /// Maximum count to display (shows "99+" if exceeded)
  final int maxCount;

  /// The visual style variant
  final ModernBadgeVariant variant;

  Color get _backgroundColor {
    switch (variant) {
      case ModernBadgeVariant.success:
        return AppColors.success;
      case ModernBadgeVariant.warning:
        return AppColors.warning;
      case ModernBadgeVariant.error:
        return AppColors.error;
      case ModernBadgeVariant.info:
        return AppColors.info;
      case ModernBadgeVariant.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (count == 0 && !showZero) {
      return const SizedBox.shrink();
    }

    final displayText = count > maxCount ? '$maxCount+' : count.toString();

    return Container(
      height: AppDimensions.counterBadgeSize,
      constraints: const BoxConstraints(
        minWidth: AppDimensions.counterBadgeSize,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Center(
        child: Text(
          displayText,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
