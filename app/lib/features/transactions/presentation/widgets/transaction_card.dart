import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/transaction.dart';

/// Card widget displaying transaction summary in the list
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Transaction number and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  transaction.transactionNumber,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          // Time and item count
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.spacing4),
              Text(
                DateFormatter.formatTime(transaction.transactionDate),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              const Icon(
                Icons.shopping_bag_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.spacing4),
              Text(
                '${transaction.totalQuantity} item',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          // Total amount
          Text(
            CurrencyFormatter.format(transaction.total),
            style: AppTextStyles.priceMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (transaction.isPaid) {
      return const ModernBadge.success(label: 'LUNAS');
    } else {
      return const ModernBadge.warning(label: 'HUTANG');
    }
  }
}
