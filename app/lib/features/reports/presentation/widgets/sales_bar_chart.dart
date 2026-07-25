import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/daily_sales.dart';

/// Bar chart widget for displaying daily sales trend
class SalesBarChart extends StatelessWidget {
  final List<DailySales> dailySales;
  final double height;

  const SalesBarChart({
    super.key,
    required this.dailySales,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Tidak ada data penjualan',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final maxRevenue = dailySales.map((e) => e.revenue).reduce(
        (a, b) => a > b ? a : b);

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
                final sales = dailySales[group.x.toInt()];
                return BarTooltipItem(
                  '${DateFormat('d MMM', 'id_ID').format(sales.date)}\n${CurrencyFormatter.format(sales.revenue)}\n${sales.transactionCount} transaksi',
                  AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                  ),
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
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dailySales.length) {
                    return const SizedBox();
                  }
                  final date = dailySales[index].date;
                  // Show fewer labels if there are many days
                  if (dailySales.length > 7 && index % 2 != 0) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.spacing4),
                    child: Text(
                      DateFormat('d').format(date),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == maxRevenue * 1.2) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppDimensions.spacing4),
                    child: Text(
                      CurrencyFormatter.formatCompact(value),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxRevenue > 0 ? maxRevenue / 4 : 1,
            getDrawingHorizontalLine: (value) {
              return const FlLine(
                color: AppColors.border,
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: dailySales.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.revenue,
                  color: AppColors.primary,
                  width: dailySales.length > 20 ? 8 : 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
