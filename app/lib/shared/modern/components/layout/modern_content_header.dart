import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A content-area header for detail/form screens
///
/// Used when the shell provides the navigation header (with back button)
/// but the page needs to display contextual information like entity name
/// and action buttons within the content area.
///
/// Example:
/// ```dart
/// ModernContentHeader(
///   title: 'Nasi Goreng Spesial',
///   subtitle: 'SKU-12345',
///   actions: [
///     IconButton(icon: Icon(Icons.edit), onPressed: onEdit),
///     PopupMenuButton(...),
///   ],
/// )
/// ```
class ModernContentHeader extends StatelessWidget {
  const ModernContentHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.padding,
    this.showDivider = true,
  });

  /// Factory for product detail headers with edit and delete actions
  factory ModernContentHeader.product({
    Key? key,
    required String productName,
    String? sku,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return ModernContentHeader(
      key: key,
      title: productName,
      subtitle: sku,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          tooltip: 'Edit Produk',
          color: AppColors.textSecondary,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') onDelete();
          },
          icon: const Icon(
            Icons.more_vert,
            color: AppColors.textSecondary,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: AppColors.error),
                  SizedBox(width: AppDimensions.spacing8),
                  Text('Hapus', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The main title text
  final String title;

  /// Optional subtitle (e.g., SKU, category)
  final String? subtitle;

  /// Optional leading widget (e.g., icon, avatar)
  final Widget? leading;

  /// Action buttons to display on the right side
  final List<Widget>? actions;

  /// Custom padding, defaults to spacing16
  final EdgeInsets? padding;

  /// Whether to show a divider below the header
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: padding ?? const EdgeInsets.all(AppDimensions.spacing16),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppDimensions.spacing12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppDimensions.spacing4),
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
              if (actions != null) ...actions!,
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider,
          ),
      ],
    );
  }
}
