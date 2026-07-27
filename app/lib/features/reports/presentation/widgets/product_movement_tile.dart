import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/product_movement.dart';

/// One row of the inventory movement report.
///
/// Serves both the turnover ranking and the slow-moving list; [showTurnover]
/// switches which metric gets the emphasis.
class ProductMovementTile extends StatelessWidget {
  final ProductMovement movement;

  /// Lead with turnover rather than with the tied-up capital warning.
  final bool showTurnover;

  const ProductMovementTile({
    super.key,
    required this.movement,
    this.showTurnover = true,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movement.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      movement.sku,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Terjual',
                  value: '${movement.quantitySold}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Stok',
                  value: '${movement.currentStock}',
                  valueColor: movement.isOutOfStock ? AppColors.error : null,
                ),
              ),
              Expanded(
                child: showTurnover
                    ? _Metric(
                        label: 'Perputaran',
                        // Null means undefined (no stock value to divide by),
                        // which is different from a genuine zero.
                        value: movement.turnoverRatio == null
                            ? '-'
                            : '${movement.turnoverRatio!.toStringAsFixed(2)}x',
                      )
                    : _Metric(
                        label: 'Nilai Stok',
                        value: CurrencyFormatter.formatCompact(
                          movement.stockValue,
                        ),
                        valueColor: AppColors.warning,
                      ),
              ),
              Expanded(
                child: _Metric(
                  label: showTurnover ? 'Laba' : 'Cukup',
                  value: showTurnover
                      ? CurrencyFormatter.formatCompact(movement.totalProfit)
                      : _daysOfSupplyLabel(),
                  valueColor: showTurnover ? AppColors.success : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _daysOfSupplyLabel() {
    final days = movement.daysOfSupply;
    if (days == null) return '-';
    // Beyond a year the precise figure stops being actionable and the number
    // just gets noisy.
    if (days > 365) return '>1thn';
    return '${days.round()} hr';
  }

  Widget _statusBadge() {
    if (movement.isDeadStock) {
      return const ModernBadge.error(label: 'Tidak Laku');
    }
    if (movement.isSlowMoving) {
      return const ModernBadge.warning(label: 'Lambat');
    }
    if (movement.isOutOfStock) {
      return const ModernBadge.neutral(label: 'Stok Habis');
    }
    return const ModernBadge.success(label: 'Lancar');
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Metric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
