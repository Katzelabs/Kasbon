import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A Modern-styled summary row for displaying label-value pairs
///
/// Example:
/// ```dart
/// ModernSummaryRow(label: 'Subtotal', value: 'Rp 75.000')
/// ModernSummaryRow.total(label: 'Total', value: 'Rp 77.500')
/// ModernSummaryRow.subtotal(label: 'Subtotal', value: 'Rp 70.000')
/// ```
class ModernSummaryRow extends StatelessWidget {
  const ModernSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.isHighlighted = false,
    this.isBold = false,
    this.padding,
  });

  /// Creates a total row with bold styling and primary color
  factory ModernSummaryRow.total({
    Key? key,
    required String label,
    required String value,
    Color? valueColor,
    EdgeInsets? padding,
  }) {
    return ModernSummaryRow(
      key: key,
      label: label,
      value: value,
      isBold: true,
      isHighlighted: true,
      valueStyle: AppTextStyles.priceMedium.copyWith(
        color: valueColor ?? AppColors.primary,
        fontWeight: FontWeight.bold,
      ),
      padding: padding,
    );
  }

  /// Creates a subtotal row with medium weight
  factory ModernSummaryRow.subtotal({
    Key? key,
    required String label,
    required String value,
    EdgeInsets? padding,
  }) {
    return ModernSummaryRow(
      key: key,
      label: label,
      value: value,
      isBold: true,
      padding: padding,
    );
  }

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool isHighlighted;
  final bool isBold;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final defaultLabelStyle = isBold
        ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)
        : AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary);

    final defaultValueStyle = isBold
        ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)
        : AppTextStyles.bodyMedium;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(
        vertical: AppDimensions.spacing4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: labelStyle ?? defaultLabelStyle,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Text(
            value,
            style: valueStyle ?? defaultValueStyle,
          ),
        ],
      ),
    );
  }
}

/// A Modern-styled summary section with multiple rows
///
/// Example:
/// ```dart
/// ModernSummarySection(
///   rows: [
///     ModernSummaryRow(label: 'Subtotal', value: 'Rp 75.000'),
///     ModernSummaryRow(label: 'Pajak (10%)', value: 'Rp 7.500'),
///   ],
///   totalLabel: 'Total',
///   totalValue: 'Rp 82.500',
/// )
/// ```
class ModernSummarySection extends StatelessWidget {
  const ModernSummarySection({
    super.key,
    required this.rows,
    this.showDivider = true,
    this.totalLabel,
    this.totalValue,
    this.padding,
  });

  final List<ModernSummaryRow> rows;
  final bool showDivider;
  final String? totalLabel;
  final String? totalValue;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...rows,
          if (totalLabel != null && totalValue != null) ...[
            if (showDivider)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimensions.spacing8),
                child: Divider(
                  color: AppColors.divider,
                  height: 1,
                ),
              ),
            ModernSummaryRow.total(
              label: totalLabel!,
              value: totalValue!,
            ),
          ],
        ],
      ),
    );
  }
}
