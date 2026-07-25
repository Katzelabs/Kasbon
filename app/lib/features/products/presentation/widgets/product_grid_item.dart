import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/components/card/modern_card.dart';
import '../../domain/entities/product.dart';
import 'stock_indicator.dart';

/// Grid item widget for product list
/// Displays product image, name, price, and stock indicator in a card format
/// Supports selection mode with long-press to enter selection and tap to toggle
class ProductGridItem extends StatelessWidget {
  const ProductGridItem({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  final Product product;
  final VoidCallback onTap;

  /// Callback when item is long-pressed (used to enter selection mode)
  final VoidCallback? onLongPress;

  /// Whether selection mode is active (shows checkbox overlay)
  final bool isSelectionMode;

  /// Whether this item is currently selected
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    // Detect tablet mode for responsive styling
    final isTablet = MediaQuery.of(context).size.width >= 900;

    return GestureDetector(
      onLongPress: onLongPress,
      child: ModernCard.outlined(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderColor: isSelected ? AppColors.primary : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with selection checkbox overlay
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top:
                                      Radius.circular(AppDimensions.radiusMedium),
                                ),
                                child: _buildImage(),
                              )
                            : _buildPlaceholderIcon(),
                  ),
                  // Selection checkbox overlay
                  if (isSelectionMode)
                    Positioned(
                      top: AppDimensions.spacing8,
                      right: AppDimensions.spacing8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSmall),
                          border: Border.all(
                            color:
                                isSelected ? AppColors.primary : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: AppColors.onPrimary,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            // Product Info - wrapped in Expanded to prevent overflow
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Use compact layout on tablet, spaceBetween on mobile
                  mainAxisAlignment: isTablet
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name - larger font on tablet
                    Text(
                      product.name,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 14 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Small gap on tablet for compact layout
                    if (isTablet) const SizedBox(height: 2),
                    // SKU
                    Text(
                      product.sku,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Push price/stock to bottom on tablet
                    if (isTablet) const Spacer(),
                    // Price and Stock Row - larger font on tablet
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Flexible(
                          child: Text(
                            CurrencyFormatter.format(product.sellingPrice),
                            style: AppTextStyles.priceSmall.copyWith(
                              color: AppColors.primary,
                              fontSize: isTablet ? 14 : 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacing4),
                        // Stock Indicator
                        StockIndicator(
                          stock: product.stock,
                          minStock: product.minStock,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imagePath = product.imageUrl!;
    final isLocalFile =
        imagePath.startsWith('/') || imagePath.startsWith('file://');

    if (isLocalFile) {
      final file = File(imagePath.replaceFirst('file://', ''));
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
      );
    }

    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
    );
  }

  Widget _buildPlaceholderIcon() {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: AppDimensions.iconXLarge,
        color: AppColors.textTertiary,
      ),
    );
  }
}
