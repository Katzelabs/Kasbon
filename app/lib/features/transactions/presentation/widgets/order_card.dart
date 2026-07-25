import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';

/// Order status types
enum OrderStatus { pending, inProgress, ready, completed, cancelled }

/// Order card widget for displaying order summaries
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.orderNumber,
    required this.itemCount,
    this.status = OrderStatus.pending,
    this.onTap,
    this.isSelected = false,
  });

  final String orderNumber;
  final int itemCount;
  final OrderStatus status;
  final VoidCallback? onTap;
  final bool isSelected;

  String get _statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.inProgress:
        return 'Diproses';
      case OrderStatus.ready:
        return 'Siap Disajikan';
      case OrderStatus.completed:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  ModernBadgeVariant get _badgeVariant {
    switch (status) {
      case OrderStatus.pending:
        return ModernBadgeVariant.neutral;
      case OrderStatus.inProgress:
        return ModernBadgeVariant.warning;
      case OrderStatus.ready:
        return ModernBadgeVariant.success;
      case OrderStatus.completed:
        return ModernBadgeVariant.info;
      case OrderStatus.cancelled:
        return ModernBadgeVariant.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      borderColor: isSelected ? AppColors.primary : AppColors.border,
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_outlined,
                size: AppDimensions.iconMedium,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                orderNumber,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$itemCount Item',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          SizedBox(
            width: double.infinity,
            child: ModernBadge(
              label: _statusLabel,
              variant: _badgeVariant,
              showDot: true,
            ),
          ),
        ],
      ),
    );
  }
}
