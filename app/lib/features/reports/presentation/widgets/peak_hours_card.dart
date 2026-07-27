import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/heatmap_cell.dart';

/// Peak-hours summary derived from the heatmap.
///
/// Turns the grid into the plain-language answers a shop owner actually wants:
/// when to be fully staffed, and which day is worth a promotion.
class PeakHoursCard extends StatelessWidget {
  final HourlyHeatmap heatmap;

  const PeakHoursCard({super.key, required this.heatmap});

  @override
  Widget build(BuildContext context) {
    if (heatmap.isEmpty) {
      return ModernCard.outlined(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Text(
          'Belum cukup data untuk menganalisis jam sibuk',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final topHours = heatmap.topHours(count: 3);
    final busiestDay = heatmap.busiestDay;
    final quietestDay = heatmap.quietestDay;
    final revenueByHour = heatmap.revenueByHour;

    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: AppDimensions.iconMedium,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Jam Sibuk',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          if (topHours.isEmpty)
            Text(
              'Belum ada pola jam yang jelas',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (var i = 0; i < topHours.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
                child: _HourRow(
                  rank: i + 1,
                  hour: topHours[i],
                  revenue: revenueByHour[topHours[i]] ?? 0,
                  transactionCount:
                      heatmap.transactionsByHour[topHours[i]] ?? 0,
                ),
              ),
          if (busiestDay != null) ...[
            const SizedBox(height: AppDimensions.spacing8),
            const ModernDivider(),
            const SizedBox(height: AppDimensions.spacing12),
            Row(
              children: [
                Expanded(
                  child: _DayStat(
                    label: 'Hari Teramai',
                    day: kWeekdayLabelsLong[busiestDay - 1],
                    color: AppColors.success,
                  ),
                ),
                if (quietestDay != null && quietestDay != busiestDay)
                  Expanded(
                    child: _DayStat(
                      label: 'Hari Tersepi',
                      day: kWeekdayLabelsLong[quietestDay - 1],
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  final int rank;
  final int hour;
  final double revenue;
  final int transactionCount;

  const _HourRow({
    required this.rank,
    required this.hour,
    required this.revenue,
    required this.transactionCount,
  });

  Color get _rankColor => switch (rank) {
        1 => AppColors.rankGold,
        2 => AppColors.rankSilver,
        _ => AppColors.rankBronze,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _rankColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: Text(
            '$rank',
            style: AppTextStyles.bodySmall.copyWith(
              color: _rankColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: Text(
            // The bucket covers the whole hour, so show it as a range rather
            // than a single instant.
            '${hour.toString().padLeft(2, '0')}:00 - '
            '${((hour + 1) % 24).toString().padLeft(2, '0')}:00',
            style: AppTextStyles.bodyMedium,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(revenue),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$transactionCount transaksi',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayStat extends StatelessWidget {
  final String label;
  final String day;
  final Color color;

  const _DayStat({
    required this.label,
    required this.day,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
          day,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
