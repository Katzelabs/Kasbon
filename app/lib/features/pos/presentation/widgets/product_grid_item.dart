import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/adaptive_local_image.dart';
import '../../../../shared/modern/modern.dart';
import '../../../products/domain/entities/product.dart';

/// Product card widget for POS grid display
///
/// Shows product image, name, price, and stock status.
/// Tapping adds the product to cart.
class ProductGridItem extends StatelessWidget {
  const ProductGridItem({
    super.key,
    required this.product,
    required this.onTap,
    this.quantityInCart = 0,
  });

  /// The product to display
  final Product product;

  /// Callback when the product is tapped
  final VoidCallback onTap;

  /// Current quantity of this product in cart (for visual feedback)
  final int quantityInCart;

  /// Whether this product is disabled (out of stock)
  bool get _isDisabled => product.isOutOfStock;

  @override
  Widget build(BuildContext context) {
    final hasInCart = quantityInCart > 0;

    return Opacity(
      opacity: _isDisabled ? 0.5 : 1.0,
      child: ModernCard.outlined(
        padding: EdgeInsets.zero,
        borderColor: hasInCart ? AppColors.primary : AppColors.border,
        onTap: _isDisabled ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image - absorbs whatever height the text leaves over.
            Expanded(
              child: Stack(
                children: [
                  _buildImage(),
                  // Stock badge
                  if (product.isOutOfStock || product.isLowStock)
                    Positioned(
                      top: AppDimensions.spacing8,
                      right: AppDimensions.spacing8,
                      child: _buildStockBadge(),
                    ),
                  // Quantity in cart badge
                  if (hasInCart)
                    Positioned(
                      top: AppDimensions.spacing8,
                      left: AppDimensions.spacing8,
                      child: _buildCartBadge(),
                    ),
                ],
              ),
            ),
            // Product info.
            //
            // Sized to its text rather than to a share of the tile, and the
            // image above takes whatever is left. The three lines here have a
            // fixed height - a name, a price and a stock line - so giving them a
            // proportion of the tile is a bet that the proportion is always
            // larger than the text, and it was not: at the tile geometry a
            // phone produces, the old `Expanded(flex: 2)` was 19px short and the
            // card overflowed.
            //
            // That bet used to be safe-ish because a fixed column count gave
            // only a handful of possible tile sizes. The grid now sizes tiles by
            // max extent, so every width between 2 and 9 columns is reachable
            // and the text must not depend on the tile's proportions at all.
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    product.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spacing4),
                  // Price
                  Text(
                    CurrencyFormatter.format(product.sellingPrice),
                    style: AppTextStyles.priceMedium.copyWith(
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  // Stock info
                  Text(
                    'Stok: ${product.stock} ${product.unit}',
                    style: AppTextStyles.caption.copyWith(
                      color: product.isOutOfStock
                          ? AppColors.error
                          : product.isLowStock
                              ? AppColors.warning
                              : AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
      ),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusLarge),
              ),
              child: _buildImageContent(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildImageContent() {
    final imagePath = product.imageUrl!;
    final isLocalFile =
        imagePath.startsWith('/') || imagePath.startsWith('file://');

    if (isLocalFile) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: AdaptiveLocalImage(
          path: imagePath,
          fallback: (_) => _buildPlaceholder(),
        ),
      );
    }

    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 48,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _buildStockBadge() {
    if (product.isOutOfStock) {
      return const ModernBadge.error(label: 'Habis');
    } else if (product.isLowStock) {
      return const ModernBadge.warning(label: 'Stok Rendah');
    }
    return const SizedBox.shrink();
  }

  Widget _buildCartBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing8,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Text(
        '$quantityInCart',
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
