import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// One row in a settings group.
///
/// This used to render its own [ModernCard.outlined], so a section of four
/// options was four bordered cards stacked with 8dp of background showing
/// between them. Every row therefore announced itself as a separate object,
/// which is a lot of visual weight for what is really one list. The card now
/// belongs to [SettingsSection] and a tile is just a row inside it, separated
/// from its neighbours by a hairline.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;

  /// Rendered in place of [subtitle] when supplied.
  ///
  /// Exists for the hub's loading state: the two rows whose subtitles come from
  /// the server show a skeleton line there instead of the whole screen being
  /// replaced by a spinner.
  final Widget? subtitleWidget;

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
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.isDestructive = false,
  });

  /// The left inset a divider needs to clear the icon chip and line up with the
  /// title, rather than cutting the row in half edge to edge.
  static const double dividerIndent =
      AppDimensions.spacing16 + _chipSize + AppDimensions.spacing16;

  static const double _chipSize =
      AppDimensions.iconMedium + AppDimensions.spacing12 * 2;

  /// Factory for navigation tile with chevron
  factory SettingsTile.navigation({
    Key? key,
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    required VoidCallback onTap,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
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
        size: AppDimensions.iconMedium,
        color: AppColors.textTertiary,
      ),
    );
  }

  /// Factory for a row that only reports a value and cannot be tapped.
  factory SettingsTile.info({
    Key? key,
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      showChevron: false,
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
    final resolvedSubtitle = subtitleWidget ??
        (subtitle != null
            ? Text(
                subtitle!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null);

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: _chipSize,
            height: _chipSize,
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
                if (resolvedSubtitle != null) ...[
                  const SizedBox(height: AppDimensions.spacing4),
                  resolvedSubtitle,
                ],
              ],
            ),
          ),

          // Trailing widget or chevron
          if (trailing != null) ...[
            const SizedBox(width: AppDimensions.spacing12),
            trailing!,
          ] else if (showChevron)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );

    if (onTap == null) return row;

    // Material + InkWell rather than the card's own onTap, because the card is
    // now the whole group: a ripple on it would light up every row at once.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }
}
