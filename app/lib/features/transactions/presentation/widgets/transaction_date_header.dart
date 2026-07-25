import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';

/// Sticky date header for transaction groups in the list
class TransactionDateHeader extends StatelessWidget {
  const TransactionDateHeader({
    super.key,
    required this.date,
  });

  final DateTime date;

  /// Fixed height for the sticky header
  static const double headerHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final relativeDate = DateFormatter.getRelativeTime(date);
    final formattedDate = DateFormatter.formatDayMonth(date);

    return Container(
      height: headerHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
      ),
      color: AppColors.background,
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Text(
            relativeDate,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Flexible(
            child: Text(
              '- $formattedDate ${date.year}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
