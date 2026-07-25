import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';

/// Product card widget for displaying product items in POS grid
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.productName,
    required this.productPrice,
    this.productImage,
    this.quantity = 0,
    this.stockCount,
    this.isSelected = false,
    this.onTap,
    this.onAddToCart,
    this.onQuantityChanged,
  });

  final String productName;
  final String productPrice;
  final String? productImage;
  final int quantity;
  final int? stockCount;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final ValueChanged<int>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: EdgeInsets.zero,
      borderColor: isSelected ? AppColors.primary : AppColors.border,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImage(),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductInfo(),
                const SizedBox(height: AppDimensions.spacing8),
                _buildAction(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    if (productImage == null || productImage!.isEmpty) {
      return _buildPlaceholder();
    }

    // Check if it's a local file path
    final isLocalFile = productImage!.startsWith('/') ||
        productImage!.startsWith('file://');

    if (isLocalFile) {
      final file = File(productImage!.replaceFirst('file://', ''));
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    // Network URL
    return Image.network(
      productImage!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          productName,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppDimensions.spacing2),
        Row(
          children: [
            Text(
              productPrice,
              style: AppTextStyles.priceSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (stockCount != null) ...[
              const Spacer(),
              Text(
                'Stok: $stockCount',
                style: AppTextStyles.caption.copyWith(
                  color: stockCount! > 0 ? AppColors.textTertiary : AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAction() {
    if (quantity > 0 && onQuantityChanged != null) {
      return Row(
        children: [
          ModernButton.primary(
            leadingIcon: Icons.check,
            size: ModernSize.small,
            onPressed: onTap,
            child: const Text('Pilih'),
          ),
          const Spacer(),
          ModernQuantityStepper.compact(
            value: quantity,
            onChanged: onQuantityChanged!,
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ModernButton.outline(
        leadingIcon: Icons.add,
        size: ModernSize.small,
        onPressed: onAddToCart,
        child: const Text('Tambah'),
      ),
    );
  }
}
