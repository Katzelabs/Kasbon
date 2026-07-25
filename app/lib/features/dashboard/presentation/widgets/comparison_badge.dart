import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// Badge showing percentage change from yesterday
class ComparisonBadge extends StatelessWidget {
  /// The percentage change (can be negative)
  final double? percentage;

  /// Whether the change is an increase
  final bool isIncrease;

  const ComparisonBadge({
    super.key,
    required this.percentage,
    required this.isIncrease,
  });

  @override
  Widget build(BuildContext context) {
    // No comparison data available
    if (percentage == null) {
      return Text(
        'Belum ada data kemarin',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      );
    }

    final color = isIncrease ? AppColors.success : AppColors.error;
    final icon = isIncrease ? Icons.arrow_upward : Icons.arrow_downward;
    final prefix = isIncrease ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing8,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppDimensions.spacing4),
          Text(
            '$prefix${percentage!.toStringAsFixed(1)}% dari kemarin',
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
