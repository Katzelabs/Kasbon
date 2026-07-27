import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/sales_trend_point.dart';

/// Line chart of revenue and (optionally) profit over time.
///
/// Expects a gap-filled series - see [SalesTrendPointX.fillGaps] - so the
/// x-axis has no holes and a quiet day reads as a dip rather than vanishing.
class SalesTrendLineChart extends StatelessWidget {
  final List<SalesTrendPoint> points;

  /// Draw the profit line alongside revenue.
  final bool showProfit;

  final double height;

  const SalesTrendLineChart({
    super.key,
    required this.points,
    this.showProfit = true,
    this.height = 220,
  });

  /// Format a bucket for the x-axis, matching its granularity.
  String _axisLabel(SalesTrendPoint point) {
    switch (point.granularity) {
      case TrendGranularity.day:
        return DateFormat('d/M', 'id_ID').format(point.bucketStart);
      case TrendGranularity.week:
        return DateFormat('d MMM', 'id_ID').format(point.bucketStart);
      case TrendGranularity.month:
        return DateFormat('MMM', 'id_ID').format(point.bucketStart);
    }
  }

  /// Full label for the tooltip.
  String _tooltipLabel(SalesTrendPoint point) {
    switch (point.granularity) {
      case TrendGranularity.day:
        return DateFormat('EEEE, d MMM', 'id_ID').format(point.bucketStart);
      case TrendGranularity.week:
        return 'Minggu ${DateFormat('d MMM', 'id_ID').format(point.bucketStart)}';
      case TrendGranularity.month:
        return DateFormat('MMMM yyyy', 'id_ID').format(point.bucketStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
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

    // Scale to the largest value on either line so neither is clipped. Profit
    // can be negative, so the floor is the lowest profit rather than zero.
    final maxRevenue = points.maxRevenue;
    final maxProfit = showProfit ? points.maxProfit : 0.0;
    final rawMax = maxRevenue > maxProfit ? maxRevenue : maxProfit;
    final maxY = rawMax <= 0 ? 1.0 : rawMax * 1.2;

    final minProfit = showProfit
        ? points.map((p) => p.profit).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final minY = minProfit < 0 ? minProfit * 1.2 : 0.0;

    // With many buckets, label every nth point so they do not overlap.
    final labelStride = (points.length / 6).ceil().clamp(1, points.length);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppColors.secondary,
              tooltipPadding: const EdgeInsets.all(AppDimensions.spacing8),
              tooltipMargin: AppDimensions.spacing8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) {
                if (touchedSpots.isEmpty) return [];
                final index = touchedSpots.first.x.toInt();
                if (index < 0 || index >= points.length) return [];
                final point = points[index];

                // Only the first spot carries the header, otherwise the label
                // repeats once per line.
                return touchedSpots.asMap().entries.map((entry) {
                  final isFirst = entry.key == 0;
                  final isRevenue = entry.value.barIndex == 0;
                  final value = isRevenue ? point.revenue : point.profit;
                  final label = isRevenue ? 'Pendapatan' : 'Laba';

                  return LineTooltipItem(
                    '${isFirst ? '${_tooltipLabel(point)}\n' : ''}'
                    '$label: ${CurrencyFormatter.format(value)}',
                    AppTextStyles.bodySmall.copyWith(color: Colors.white),
                  );
                }).toList();
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
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  // Always keep the final label so the range end is readable.
                  final isLast = index == points.length - 1;
                  if (index % labelStride != 0 && !isLast) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.spacing4),
                    child: Text(
                      _axisLabel(points[index]),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
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
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
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
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _line(
              values: points.map((p) => p.revenue).toList(),
              color: AppColors.primary,
              withGradient: true,
            ),
            if (showProfit)
              _line(
                values: points.map((p) => p.profit).toList(),
                color: AppColors.success,
                withGradient: false,
              ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line({
    required List<double> values,
    required Color color,
    required bool withGradient,
  }) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      // Keeps the curve from overshooting into negative territory between two
      // positive points, which would imply a loss that never happened.
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      // Individual dots become noise beyond a couple of weeks of buckets.
      dotData: FlDotData(show: values.length <= 14),
      belowBarData: BarAreaData(
        show: withGradient,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// Colour key for the trend chart's two lines.
class SalesTrendLegend extends StatelessWidget {
  final bool showProfit;

  const SalesTrendLegend({super.key, this.showProfit = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _LegendDot(color: AppColors.primary, label: 'Pendapatan'),
        if (showProfit) ...[
          const SizedBox(width: AppDimensions.spacing16),
          const _LegendDot(color: AppColors.success, label: 'Laba'),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDimensions.spacing4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
