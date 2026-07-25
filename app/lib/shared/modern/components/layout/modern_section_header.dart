import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A Modern-styled section header with title and optional action
///
/// Example:
/// ```dart
/// ModernSectionHeader(title: 'Menu Items', subtitle: '12 produk')
/// ModernSectionHeader.withSeeAll(
///   title: 'Produk Terlaris',
///   onSeeAll: () => context.push('/products'),
/// )
/// ```
class ModernSectionHeader extends StatelessWidget {
  const ModernSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.actionLabel,
    this.onActionTap,
    this.padding,
  });

  /// Creates a section header with a "See All" action
  factory ModernSectionHeader.withSeeAll({
    Key? key,
    required String title,
    String? subtitle,
    required VoidCallback onSeeAll,
  }) {
    return ModernSectionHeader(
      key: key,
      title: title,
      subtitle: subtitle,
      actionLabel: 'Lihat Semua',
      onActionTap: onSeeAll,
    );
  }

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h4,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimensions.spacing2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null && onActionTap != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionLabel!,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
