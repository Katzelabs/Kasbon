import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/period_comparison.dart';

/// Compares the selected period against the one immediately before it.
class PeriodComparisonCard extends StatelessWidget {
  final PeriodComparison comparison;

  const PeriodComparisonCard({super.key, required this.comparison});

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows_rounded,
                size: AppDimensions.iconMedium,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  'Dibanding Periode Sebelumnya',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!comparison.hasBaseline) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              'Tidak ada transaksi pada periode sebelumnya',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.spacing16),
          _MetricRow(
            label: 'Pendapatan',
            change: comparison.revenue,
            formatValue: CurrencyFormatter.format,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          _MetricRow(
            label: 'Laba',
            change: comparison.profit,
            formatValue: CurrencyFormatter.format,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          _MetricRow(
            label: 'Transaksi',
            change: comparison.transactionCount,
            formatValue: (value) => value.toStringAsFixed(0),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          _MetricRow(
            label: 'Rata-rata / Transaksi',
            change: comparison.averageTransactionValue,
            formatValue: CurrencyFormatter.format,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final MetricChange change;
  final String Function(double) formatValue;

  const _MetricRow({
    required this.label,
    required this.change,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                formatValue(change.current),
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _ChangeIndicator(change: change),
      ],
    );
  }
}

/// The delta badge: an arrow plus a percentage, or "Baru" when there is no
/// baseline to compute a percentage against.
class _ChangeIndicator extends StatelessWidget {
  final MetricChange change;

  const _ChangeIndicator({required this.change});

  @override
  Widget build(BuildContext context) {
    if (change.isNewActivity) {
      return const ModernBadge.success(label: 'Baru');
    }

    if (change.direction == ChangeDirection.flat) {
      return Text(
        'Tetap',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      );
    }

    final percent = change.percentChange;
    if (percent == null) {
      return const SizedBox.shrink();
    }

    final isUp = change.direction == ChangeDirection.up;
    final color = isUp ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing8,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${percent.abs().toStringAsFixed(1)}%',
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
