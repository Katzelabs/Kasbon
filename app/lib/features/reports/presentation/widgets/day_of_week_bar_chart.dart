import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/heatmap_cell.dart';

/// Revenue per weekday, derived from the same heatmap payload.
///
/// Always renders all seven bars, including days with no sales - a missing
/// Sunday bar would read as "no data" when it actually means "closed", which
/// is exactly the fact the shop needs to see.
class DayOfWeekBarChart extends StatelessWidget {
  final HourlyHeatmap heatmap;
  final double height;

  const DayOfWeekBarChart({
    super.key,
    required this.heatmap,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final revenueByDay = heatmap.revenueByDay;
    final transactionsByDay = heatmap.transactionsByDay;
    final busiest = heatmap.busiestDay;

    final maxRevenue = revenueByDay.values.isEmpty
        ? 0.0
        : revenueByDay.values.reduce((a, b) => a > b ? a : b);

    if (maxRevenue <= 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Tidak ada data',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.2,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: AppColors.secondary,
              tooltipPadding: const EdgeInsets.all(AppDimensions.spacing8),
              tooltipMargin: AppDimensions.spacing8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = group.x.toInt();
                return BarTooltipItem(
                  '${kWeekdayLabelsLong[day - 1]}\n'
                  '${CurrencyFormatter.format(revenueByDay[day] ?? 0)}\n'
                  '${transactionsByDay[day] ?? 0} transaksi',
                  AppTextStyles.bodySmall.copyWith(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day < 1 || day > 7) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.spacing4),
                    child: Text(
                      kWeekdayLabelsShort[day - 1],
                      style: AppTextStyles.bodySmall.copyWith(
                        color: day == busiest
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontWeight: day == busiest
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    CurrencyFormatter.formatCompact(value),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxRevenue / 3,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var day = 1; day <= 7; day++)
              BarChartGroupData(
                x: day,
                barRods: [
                  BarChartRodData(
                    toY: revenueByDay[day] ?? 0,
                    // The busiest day is highlighted so the comparison reads at
                    // a glance without needing the tooltip.
                    color: day == busiest
                        ? AppColors.primary
                        : AppColors.primaryLight.withValues(alpha: 0.55),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
