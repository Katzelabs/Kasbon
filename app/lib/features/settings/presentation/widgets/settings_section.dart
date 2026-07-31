import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import 'settings_tile.dart';

/// A titled group of settings rows.
///
/// The group owns one card and the rows sit inside it, divided by hairlines -
/// the shape a settings list has on both platforms it ships to. It used to be
/// the other way round: each [SettingsTile] carried its own outlined card and
/// the section merely spaced them 8dp apart, which read as a stack of unrelated
/// panels rather than one list with a heading.
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  /// Optional trailing widget for the section heading, e.g. a status chip.
  final Widget? headerTrailing;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.padding,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // The heading sits just inside the card's left edge rather than
            // flush with it, so the eye reads one column.
            padding: const EdgeInsets.only(left: AppDimensions.spacing4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (headerTrailing != null) headerTrailing!,
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          ModernCard.outlined(
            padding: EdgeInsets.zero,
            // So a row's ink ripple stops at the rounded corner instead of
            // squaring it off.
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: SettingsTile.dividerIndent,
                      color: AppColors.borderLight,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
