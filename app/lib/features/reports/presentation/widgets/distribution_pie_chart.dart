import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';

/// One slice of a distribution pie chart, independent of what it represents.
///
/// Both the category and payment-method charts feed this, so the rendering and
/// legend behaviour stay identical between them.
class PieSliceData {
  final String label;
  final double value;
  final Color color;

  /// Optional secondary line in the legend, e.g. units sold.
  final String? detail;

  const PieSliceData({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });
}

/// A donut chart with a tappable legend.
///
/// Percentages are computed against the series total here rather than being
/// taken from the backend, so the slices always sum to exactly 100%.
class DistributionPieChart extends StatefulWidget {
  final List<PieSliceData> slices;

  /// Label for the value shown in the middle of the donut.
  final String centerLabel;

  final double height;

  const DistributionPieChart({
    super.key,
    required this.slices,
    this.centerLabel = 'Total',
    this.height = 200,
  });

  @override
  State<DistributionPieChart> createState() => _DistributionPieChartState();
}

class _DistributionPieChartState extends State<DistributionPieChart> {
  /// Index of the slice being touched, or -1 for none.
  int _touchedIndex = -1;

  double get _total =>
      widget.slices.fold(0.0, (sum, slice) => sum + slice.value);

  @override
  Widget build(BuildContext context) {
    final total = _total;

    if (widget.slices.isEmpty || total <= 0) {
      return SizedBox(
        height: widget.height,
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

    // The highlighted slice drives the centre readout; with nothing touched it
    // shows the series total.
    final highlighted =
        _touchedIndex >= 0 && _touchedIndex < widget.slices.length
            ? widget.slices[_touchedIndex]
            : null;

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: widget.height * 0.22,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex =
                            response!.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: [
                    for (var i = 0; i < widget.slices.length; i++)
                      _section(i, widget.slices[i], total),
                  ],
                ),
              ),
              _CenterReadout(
                label: highlighted?.label ?? widget.centerLabel,
                value: CurrencyFormatter.formatCompact(
                  highlighted?.value ?? total,
                ),
                percent: highlighted == null
                    ? null
                    : (highlighted.value / total) * 100,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        _Legend(
          slices: widget.slices,
          total: total,
          touchedIndex: _touchedIndex,
          onTap: (index) => setState(
            () => _touchedIndex = _touchedIndex == index ? -1 : index,
          ),
        ),
      ],
    );
  }

  PieChartSectionData _section(int index, PieSliceData slice, double total) {
    final isTouched = index == _touchedIndex;
    final percent = (slice.value / total) * 100;
    final radius = isTouched ? widget.height * 0.32 : widget.height * 0.28;

    return PieChartSectionData(
      value: slice.value,
      color: slice.color,
      radius: radius,
      // A label inside a sliver-thin slice is unreadable, so hide it below a
      // threshold and let the legend carry those.
      title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
      titleStyle: AppTextStyles.bodySmall.copyWith(
        color: ColorUtils.onColor(slice.color),
        fontWeight: FontWeight.bold,
        fontSize: isTouched ? 13 : 11,
      ),
    );
  }
}

class _CenterReadout extends StatelessWidget {
  final String label;
  final String value;
  final double? percent;

  const _CenterReadout({
    required this.label,
    required this.value,
    this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (percent != null)
          Text(
            '${percent!.toStringAsFixed(1)}%',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final List<PieSliceData> slices;
  final double total;
  final int touchedIndex;
  final ValueChanged<int> onTap;

  const _Legend({
    required this.slices,
    required this.total,
    required this.touchedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
            child: InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacing4,
                  horizontal: AppDimensions.spacing4,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: slices[i].color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slices[i].label,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: i == touchedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (slices[i].detail != null)
                            Text(
                              slices[i].detail!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
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
                          CurrencyFormatter.format(slices[i].value),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${((slices[i].value / total) * 100).toStringAsFixed(1)}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
