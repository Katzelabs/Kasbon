import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';

/// A tile for navigation or action in settings screens
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isDestructive;

  const SettingsTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.isDestructive = false,
  });

  /// Factory for navigation tile with chevron
  factory SettingsTile.navigation({
    Key? key,
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      showChevron: true,
    );
  }

  /// Factory for external link tile
  factory SettingsTile.externalLink({
    Key? key,
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      showChevron: false,
      trailing: const Icon(
        Icons.open_in_new_rounded,
        size: 20,
        color: AppColors.textTertiary,
      ),
    );
  }

  /// Factory for action tile (no chevron)
  factory SettingsTile.action({
    Key? key,
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      showChevron: false,
    );
  }

  /// Factory for destructive action tile
  factory SettingsTile.destructive({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      iconColor: AppColors.error,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      showChevron: false,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final titleColor = isDestructive ? AppColors.error : AppColors.textPrimary;

    return ModernCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Icon(
              icon,
              color: effectiveIconColor,
              size: AppDimensions.iconMedium,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing16),

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimensions.spacing4),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Trailing widget or chevron
          if (trailing != null)
            trailing!
          else if (showChevron)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );
  }
}
