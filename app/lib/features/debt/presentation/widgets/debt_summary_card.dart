import 'package:flutter/material.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/debt_summary.dart';

/// Summary card displaying overall debt statistics
class DebtSummaryCard extends StatelessWidget {
  const DebtSummaryCard({
    super.key,
    required this.summary,
  });

  final DebtSummary summary;

  @override
  Widget build(BuildContext context) {
    return ModernGradientCard.primary(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: AppDimensions.iconLarge,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Text(
                'Total Hutang',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Total amount
          Text(
            CurrencyFormatter.format(summary.totalDebt),
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Stats row
          Row(
            children: [
              _StatItem(
                icon: Icons.people_outline,
                value: '${summary.customerCount}',
                label: 'Pelanggan',
              ),
              const SizedBox(width: AppDimensions.spacing24),
              _StatItem(
                icon: Icons.receipt_long_outlined,
                value: '${summary.transactionCount}',
                label: 'Transaksi',
              ),
            ],
          ),

          // Oldest debt info
          if (summary.oldestDebtDate != null) ...[
            const SizedBox(height: AppDimensions.spacing12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing12,
                vertical: AppDimensions.spacing8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Colors.white,
                    size: AppDimensions.iconSmall,
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Text(
                    'Hutang tertua: ${DateFormatter.getRelativeTime(summary.oldestDebtDate!)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stat item for summary card
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.8),
          size: AppDimensions.iconMedium,
        ),
        const SizedBox(width: AppDimensions.spacing8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
