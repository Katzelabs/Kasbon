import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/dashboard_summary.dart';
import 'comparison_badge.dart';

/// Sales summary card showing today's sales, profit, and comparison
class SalesSummaryCard extends StatelessWidget {
  final DashboardSummary summary;
  final VoidCallback? onTap;

  const SalesSummaryCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // No inset of its own. It used to carry a 16dp one, which was fine while
    // the only caller stacked it in a full-width column; the dashboard now also
    // puts it in a Row beside the low-stock alert, where a padded card cannot
    // sit flush against its neighbour. The screen owns the spacing.
    return ModernCard.elevated(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacing8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              // Flexible, not bare: this card is now also a column of the
              // expanded and large layouts, where it is a good deal narrower
              // than the full-width card it used to be. An unbounded Text in a
              // Row overflows rather than wrapping.
              Flexible(
                child: Text(
                  'Penjualan Hari Ini',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Main sales figure
          Text(
            CurrencyFormatter.format(summary.todaySales),
            style: AppTextStyles.priceLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing8),

          // Comparison badge
          ComparisonBadge(
            percentage: summary.comparisonPercentage,
            isIncrease: summary.isIncrease,
          ),

          const SizedBox(height: AppDimensions.spacing16),

          const ModernDivider(),

          const SizedBox(height: AppDimensions.spacing16),

          // Stats row
          Row(
            children: [
              // Profit stat
              Expanded(
                child: _StatItem(
                  icon: Icons.monetization_on_outlined,
                  label: 'Laba',
                  value: CurrencyFormatter.format(summary.todayProfit),
                  subValue: summary.todaySales > 0
                      ? '${summary.profitMargin.toStringAsFixed(0)}%'
                      : null,
                  iconColor: AppColors.success,
                  comparisonPercentage: summary.profitComparisonPercentage,
                  isIncrease: summary.isProfitIncrease,
                ),
              ),

              // Divider
              Container(
                height: 60,
                width: 1,
                color: AppColors.border,
              ),

              // Transaction count stat
              Expanded(
                child: _StatItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transaksi',
                  value: summary.transactionCount.toString(),
                  iconColor: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual stat item widget
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subValue;
  final Color iconColor;
  final double? comparisonPercentage;
  final bool? isIncrease;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
    required this.iconColor,
    this.comparisonPercentage,
    this.isIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: AppDimensions.spacing4),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(width: AppDimensions.spacing4),
              Text(
                '($subValue)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
        // Profit comparison badge
        if (comparisonPercentage != null && isIncrease != null) ...[
          const SizedBox(height: AppDimensions.spacing4),
          _buildComparisonBadge(),
        ],
      ],
    );
  }

  Widget _buildComparisonBadge() {
    final color = isIncrease! ? AppColors.success : AppColors.error;
    final iconData = isIncrease! ? Icons.arrow_upward : Icons.arrow_downward;
    final prefix = isIncrease! ? '+' : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          iconData,
          size: 10,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '$prefix${comparisonPercentage!.toStringAsFixed(0)}%',
          style: AppTextStyles.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
