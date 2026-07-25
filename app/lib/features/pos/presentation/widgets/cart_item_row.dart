import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';

/// Cart item row widget for displaying items in cart/order summary
class CartItemRow extends StatelessWidget {
  const CartItemRow({
    super.key,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    this.productImage,
    this.onRemove,
    this.onTap,
  });

  final String productName;
  final String productPrice;
  final int quantity;
  final String? productImage;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacing8,
            horizontal: AppDimensions.spacing4,
          ),
          child: Row(
            children: [
              _buildImage(),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _buildInfo(),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: AppDimensions.spacing8),
                _buildRemoveButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (productImage != null && productImage!.isNotEmpty) {
      final isLocalFile =
          productImage!.startsWith('/') || productImage!.startsWith('file://');

      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: isLocalFile
            ? Image.file(
                File(productImage!.replaceFirst('file://', '')),
                width: AppDimensions.avatarLarge,
                height: AppDimensions.avatarLarge,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : Image.network(
                productImage!,
                width: AppDimensions.avatarLarge,
                height: AppDimensions.avatarLarge,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return ModernAvatar.large(
      initials: productName.isNotEmpty ? productName[0] : '?',
      backgroundColor: AppColors.surfaceVariant,
      foregroundColor: AppColors.textSecondary,
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        Text(
          '($productPrice) x $quantity',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return ModernIconButton.standard(
      icon: Icons.delete_outline,
      size: ModernSize.small,
      color: AppColors.error,
      onPressed: onRemove,
      tooltip: 'Hapus',
    );
  }
}
