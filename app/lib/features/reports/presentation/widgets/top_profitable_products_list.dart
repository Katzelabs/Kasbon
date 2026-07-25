import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/product_profitability.dart';

/// Widget displaying a list of top profitable products
class TopProfitableProductsList extends StatelessWidget {
  final List<ProductProfitability> products;
  final Function(String productId)? onProductTap;

  const TopProfitableProductsList({
    super.key,
    required this.products,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.analytics_outlined,
        title: 'Belum Ada Data Laba',
        message: 'Mulai berjualan untuk melihat produk paling menguntungkan',
      );
    }

    return ModernCard.outlined(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) => const ModernDivider(),
        itemBuilder: (context, index) => _buildProductItem(
          context,
          products[index],
          index + 1,
        ),
      ),
    );
  }

  Widget _buildProductItem(
    BuildContext context,
    ProductProfitability product,
    int rank,
  ) {
    return InkWell(
      onTap: onProductTap != null
          ? () => onProductTap!(product.productId)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Row(
          children: [
            // Rank number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getRankColor(rank).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _getRankColor(rank),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppDimensions.spacing12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spacing4),
                  Row(
                    children: [
                      Text(
                        '${product.totalSold} terjual',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing8,
                          vertical: AppDimensions.spacing2,
                        ),
                        decoration: BoxDecoration(
                          color: _getMarginColor(product.averageMargin)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                        ),
                        child: Text(
                          '${product.averageMargin.toStringAsFixed(0)}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getMarginColor(product.averageMargin),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Profit value
            Text(
              CurrencyFormatter.format(product.totalProfit),
              style: AppTextStyles.priceMedium.copyWith(
                color: product.totalProfit >= 0
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.warning; // Gold
      case 2:
        return AppColors.textSecondary; // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.textTertiary;
    }
  }

  Color _getMarginColor(double margin) {
    if (margin >= 30) return AppColors.success;
    if (margin >= 15) return AppColors.info;
    if (margin >= 0) return AppColors.warning;
    return AppColors.error;
  }
}
