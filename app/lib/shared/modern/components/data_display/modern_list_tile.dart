import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A Modern-styled list tile with consistent theming
///
/// Example:
/// ```dart
/// ModernListTile(
///   leading: ModernAvatar.initials('JD'),
///   title: Text('John Doe'),
///   subtitle: Text('john@example.com'),
///   trailing: Icon(Icons.chevron_right),
///   onTap: () => _navigateToDetail(),
/// )
/// ```
class ModernListTile extends StatelessWidget {
  const ModernListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.dense = false,
    this.contentPadding,
    this.backgroundColor,
    this.selectedColor,
    this.borderRadius,
  });

  /// Creates a navigation list tile with chevron
  factory ModernListTile.navigation({
    Key? key,
    Widget? leading,
    required Widget title,
    Widget? subtitle,
    required VoidCallback onTap,
    bool selected = false,
    bool enabled = true,
    bool dense = false,
    EdgeInsets? contentPadding,
    Color? backgroundColor,
    Color? selectedColor,
  }) {
    return ModernListTile(
      key: key,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Icon(
        Icons.chevron_right,
        color: enabled ? AppColors.textTertiary : AppColors.textDisabled,
      ),
      onTap: onTap,
      selected: selected,
      enabled: enabled,
      dense: dense,
      contentPadding: contentPadding,
      backgroundColor: backgroundColor,
      selectedColor: selectedColor,
    );
  }

  /// Creates a list tile with a switch
  factory ModernListTile.switchTile({
    Key? key,
    Widget? leading,
    required Widget title,
    Widget? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    bool dense = false,
    EdgeInsets? contentPadding,
    Color? backgroundColor,
  }) {
    return ModernListTile(
      key: key,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: AppColors.primary,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return null;
        }),
      ),
      onTap: enabled ? () => onChanged(!value) : null,
      enabled: enabled,
      dense: dense,
      contentPadding: contentPadding,
      backgroundColor: backgroundColor,
    );
  }

  /// Creates a list tile with a checkbox
  factory ModernListTile.checkbox({
    Key? key,
    Widget? leading,
    required Widget title,
    Widget? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    bool dense = false,
    EdgeInsets? contentPadding,
    Color? backgroundColor,
  }) {
    return ModernListTile(
      key: key,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Checkbox(
        value: value,
        onChanged: enabled ? (v) => onChanged(v ?? false) : null,
        activeColor: AppColors.primary,
      ),
      onTap: enabled ? () => onChanged(!value) : null,
      enabled: enabled,
      dense: dense,
      contentPadding: contentPadding,
      backgroundColor: backgroundColor,
    );
  }

  /// The leading widget (typically an avatar or icon)
  final Widget? leading;

  /// The title widget
  final Widget? title;

  /// The subtitle widget
  final Widget? subtitle;

  /// The trailing widget
  final Widget? trailing;

  /// Callback when tapped
  final VoidCallback? onTap;

  /// Callback when long pressed
  final VoidCallback? onLongPress;

  /// Whether this tile is selected
  final bool selected;

  /// Whether this tile is enabled
  final bool enabled;

  /// Whether to use dense layout
  final bool dense;

  /// Custom content padding
  final EdgeInsets? contentPadding;

  /// Custom background color
  final Color? backgroundColor;

  /// Color when selected
  final Color? selectedColor;

  /// Custom border radius
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = selected
        ? (selectedColor ?? AppColors.primaryContainer.withValues(alpha: 0.5))
        : backgroundColor ?? Colors.transparent;

    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusMedium);

    final effectivePadding = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: dense ? AppDimensions.spacing8 : AppDimensions.spacing12,
        );

    Widget tile = Container(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: effectiveBorderRadius,
      ),
      child: Padding(
        padding: effectivePadding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppDimensions.spacing16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    DefaultTextStyle.merge(
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: enabled
                            ? (selected
                                ? AppColors.primary
                                : AppColors.textPrimary)
                            : AppColors.textDisabled,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                      child: title!,
                    ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimensions.spacing2),
                    DefaultTextStyle.merge(
                      style: AppTextStyles.bodySmall.copyWith(
                        color: enabled
                            ? AppColors.textSecondary
                            : AppColors.textDisabled,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppDimensions.spacing12),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      tile = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          borderRadius: effectiveBorderRadius,
          child: tile,
        ),
      );
    }

    return tile;
  }
}

/// A section header for list groups
class ModernListSection extends StatelessWidget {
  const ModernListSection({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.padding,
  });

  /// Creates a section with "See All" button
  factory ModernListSection.seeAll({
    Key? key,
    required String title,
    required VoidCallback onSeeAll,
    EdgeInsets? padding,
  }) {
    return ModernListSection(
      key: key,
      title: title,
      trailing: Text(
        'Lihat Semua',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primary,
        ),
      ),
      onTrailingTap: onSeeAll,
      padding: padding,
    );
  }

  /// The section title
  final String title;

  /// Optional trailing widget
  final Widget? trailing;

  /// Callback when trailing is tapped
  final VoidCallback? onTrailingTap;

  /// Custom padding
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing8,
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: trailing,
            ),
        ],
      ),
    );
  }
}
