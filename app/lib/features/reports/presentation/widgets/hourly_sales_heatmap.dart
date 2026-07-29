import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/entities/heatmap_cell.dart';
import 'report_layout.dart';

/// A 7x24 grid of sales intensity by weekday and hour.
///
/// Built by hand rather than with fl_chart, which has no heatmap primitive at
/// any version. Rows are ISO weekdays (Senin first, matching Indonesian
/// convention) and columns are hours in the shop's local time.
///
/// ## Cell size comes from the pane, never from the window
///
/// 24 legible hour columns do not fit on a phone, so below [minCellSize] * 24
/// the grid keeps that floor and scrolls horizontally - shrinking cells to fit
/// makes them untappable, which is worse than a scroll.
///
/// Given more room it grows the cells to fill instead, up to [maxCellSize].
/// That measurement is taken from the enclosing [ModernBreakpointScope], which
/// is the width this widget actually has: dropped into one cell of a
/// two-column dashboard on a 1600dp window it has ~500dp, not 1600, and sizing
/// from the window there would produce a grid four times too wide for its box.
class HourlySalesHeatmap extends StatefulWidget {
  final HourlyHeatmap heatmap;

  /// Floor on cell size. Below this the grid scrolls rather than shrinking.
  final double minCellSize;

  /// Ceiling on cell size, so a wide pane gets a legible grid rather than a
  /// chessboard.
  final double maxCellSize;

  const HourlySalesHeatmap({
    super.key,
    required this.heatmap,
    this.minCellSize = 26,
    this.maxCellSize = 44,
  });

  /// Cell size for a pane [available] logical pixels wide.
  ///
  /// Public so the sizing rule can be tested as the arithmetic it is, rather
  /// than only through 168 rendered cells.
  static double cellSizeFor(
    double available, {
    double min = 26,
    double max = 44,
  }) {
    // 34dp of that width belongs to the weekday gutter, not to the grid.
    final fit = (available - 34) / 24;
    if (fit <= min) return min;
    return math.min(fit, max);
  }

  @override
  State<HourlySalesHeatmap> createState() => _HourlySalesHeatmapState();
}

class _HourlySalesHeatmapState extends State<HourlySalesHeatmap> {
  /// Currently selected cell as (day, hour), or null.
  ({int day, int hour})? _selected;

  static const double _dayLabelWidth = 34;

  double _cellSizeFor(double available) => HourlySalesHeatmap.cellSizeFor(
        available,
        min: widget.minCellSize,
        max: widget.maxCellSize,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.heatmap.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing24),
        child: Center(
          child: Text(
            'Belum ada transaksi pada periode ini',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return ReportChartFrame(
      maxWidth: ReportChartWidths.heatmap,
      child: Builder(builder: _buildGrid),
    );
  }

  Widget _buildGrid(BuildContext context) {
    // The scope installed by ReportChartFrame, i.e. this widget's own box.
    final cellSize = _cellSizeFor(context.availableWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHourAxis(cellSize),
              const SizedBox(height: AppDimensions.spacing4),
              for (var day = 1; day <= 7; day++) _buildDayRow(day, cellSize),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _buildSelectionReadout(),
        const SizedBox(height: AppDimensions.spacing8),
        _buildIntensityLegend(),
      ],
    );
  }

  Widget _buildHourAxis(double cellSize) {
    return Row(
      children: [
        const SizedBox(width: _dayLabelWidth),
        for (var hour = 0; hour < 24; hour++)
          SizedBox(
            width: cellSize,
            child: Center(
              // Every third hour keeps the axis readable without crowding.
              child: hour % 3 == 0
                  ? Text(
                      '$hour',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _buildDayRow(int day, double cellSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: _dayLabelWidth,
            child: Text(
              kWeekdayLabelsShort[day - 1],
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
          for (var hour = 0; hour < 24; hour++) _buildCell(day, hour, cellSize),
        ],
      ),
    );
  }

  Widget _buildCell(int day, int hour, double cellSize) {
    final intensity = widget.heatmap.intensityAt(day, hour);
    final revenue = widget.heatmap.revenueAt(day, hour);
    final isSelected = _selected?.day == day && _selected?.hour == hour;

    // A cell with sales always gets a visible floor of colour, so a genuinely
    // quiet hour still reads as "some business" rather than as empty.
    final alpha = revenue > 0 ? 0.15 + (intensity * 0.85) : 0.0;

    return GestureDetector(
      onTap: revenue > 0
          ? () => setState(
                () => _selected = isSelected ? null : (day: day, hour: hour),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Container(
          width: cellSize - 2,
          height: cellSize - 2,
          decoration: BoxDecoration(
            color: revenue > 0
                ? AppColors.primary.withValues(alpha: alpha)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(3),
            border: isSelected
                ? Border.all(color: AppColors.secondary, width: 2)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionReadout() {
    final selected = _selected;
    final peak = widget.heatmap.peakCell;

    // With nothing selected, show the peak - the single most useful fact the
    // grid contains, and what most users are looking for.
    final day = selected?.day ?? peak?.dayOfWeek;
    final hour = selected?.hour ?? peak?.hourOfDay;
    if (day == null || hour == null) return const SizedBox.shrink();

    final revenue = widget.heatmap.revenueAt(day, hour);
    final count = widget.heatmap.countAt(day, hour);
    final prefix = selected == null ? 'Jam tersibuk: ' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$prefix${kWeekdayLabelsLong[day - 1]}, '
            '${hour.toString().padLeft(2, '0')}:00',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            '${CurrencyFormatter.format(revenue)} · $count transaksi',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityLegend() {
    return Row(
      children: [
        Text(
          'Sepi',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing8),
        for (final step in const [0.15, 0.35, 0.55, 0.75, 1.0])
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 18,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: step),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: AppDimensions.spacing4),
        Text(
          'Ramai',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
