import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/cart_item.dart';

/// Cart item tile widget for displaying items in cart
///
/// Shows product name, unit price, quantity stepper, subtotal, and delete button.
/// Displays stock warning if quantity exceeds available stock.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  /// The cart item to display
  final CartItem item;

  /// Callback when quantity changes
  final ValueChanged<int> onQuantityChanged;

  /// Callback when item is removed
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: item.exceedsStock ? AppColors.warningLight : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: item.exceedsStock ? AppColors.warning : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: product name and remove button
          Row(
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ModernIconButton.standard(
                icon: Icons.delete_outline,
                size: ModernSize.small,
                color: AppColors.error,
                onPressed: onRemove,
                tooltip: 'Hapus',
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          // Detail row: price, quantity, subtotal
          Row(
            children: [
              // Unit price
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.format(item.product.sellingPrice),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '/${item.product.unit}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Quantity stepper
              ModernQuantityStepper.compact(
                value: item.quantity,
                minValue: 1,
                maxValue: item.product.stock,
                onChanged: onQuantityChanged,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              // Subtotal
              Expanded(
                flex: 2,
                child: Text(
                  CurrencyFormatter.format(item.subtotal),
                  style: AppTextStyles.priceMedium.copyWith(
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          // Stock warning
          if (item.exceedsStock) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: AppDimensions.iconSmall,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.spacing4),
                Expanded(
                  child: Text(
                    'Stok tersedia: ${item.product.stock} ${item.product.unit}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                    ),
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
