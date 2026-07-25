import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';

/// Stock status indicator widget
/// Shows different badge based on stock level
class StockIndicator extends StatelessWidget {
  const StockIndicator({
    super.key,
    required this.stock,
    required this.minStock,
    this.showIcon = false,
    this.compact = false,
  });

  final int stock;
  final int minStock;
  final bool showIcon;

  /// When true, shows a compact version with stock number instead of text label
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactIndicator();
    }

    if (stock <= 0) {
      return ModernBadge.error(
        label: 'Habis',
        showDot: true,
        icon: showIcon ? Icons.warning_amber_rounded : null,
      );
    }

    if (stock <= minStock) {
      return ModernBadge.warning(
        label: 'Stok Rendah',
        showDot: true,
        icon: showIcon ? Icons.warning_amber_rounded : null,
      );
    }

    return ModernBadge.success(
      label: 'Tersedia',
      showDot: true,
      icon: showIcon ? Icons.check_circle_outline : null,
    );
  }

  Widget _buildCompactIndicator() {
    final color = stock <= 0
        ? AppColors.error
        : stock <= minStock
            ? AppColors.warning
            : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$stock',
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
