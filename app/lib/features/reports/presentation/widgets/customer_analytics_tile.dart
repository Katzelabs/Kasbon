import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/customer_analytics.dart';

/// One row of the top-customers report.
class CustomerAnalyticsTile extends StatelessWidget {
  final CustomerAnalytics customer;
  final int rank;

  const CustomerAnalyticsTile({
    super.key,
    required this.customer,
    required this.rank,
  });

  Color get _rankColor => switch (rank) {
        1 => AppColors.rankGold,
        2 => AppColors.rankSilver,
        3 => AppColors.rankBronze,
        _ => AppColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _rankColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _rankColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.customerName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${customer.transactionCount} transaksi · '
                      'rata-rata ${CurrencyFormatter.format(customer.averageTransaction)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(customer.totalSpent),
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (customer.isRepeatCustomer)
                    Text(
                      'Seumur hidup ${CurrencyFormatter.formatCompact(customer.lifetimeSpent)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (customer.hasOutstandingDebt || _lastPurchaseLabel() != null) ...[
            const SizedBox(height: AppDimensions.spacing8),
            const ModernDivider(),
            const SizedBox(height: AppDimensions.spacing8),
            Row(
              children: [
                if (_lastPurchaseLabel() != null)
                  Expanded(
                    child: Text(
                      _lastPurchaseLabel()!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                if (customer.hasOutstandingDebt)
                  ModernBadge.warning(
                    label:
                        'Hutang ${CurrencyFormatter.formatCompact(customer.outstandingDebt)}',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Relative recency, which reads better than a raw date for a shop owner
  /// scanning the list.
  String? _lastPurchaseLabel() {
    final last = customer.lastTransactionAt;
    if (last == null) return null;

    final days = customer.daysSinceLastTransaction();
    if (days == null) return null;
    if (days <= 0) return 'Terakhir belanja hari ini';
    if (days == 1) return 'Terakhir belanja kemarin';
    if (days < 30) return 'Terakhir belanja $days hari lalu';
    return 'Terakhir belanja ${DateFormat('d MMM yyyy', 'id_ID').format(last)}';
  }
}
