import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/product_report.dart';

/// List tile for displaying a ranked product in top products list
class TopProductTile extends StatelessWidget {
  final int rank;
  final ProductReport product;
  final TopProductDisplayType displayType;
  final VoidCallback? onTap;

  const TopProductTile({
    super.key,
    required this.rank,
    required this.product,
    required this.displayType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacing12,
            horizontal: AppDimensions.spacing16,
          ),
          child: Row(
            children: [
              // Rank indicator
              _buildRankIndicator(),
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
                    Text(
                      _getSubtitle(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Value
              Text(
                _getValue(),
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getValueColor(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankIndicator() {
    if (rank <= 3) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _getMedalColor(),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            rank.toString(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          rank.toString(),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getMedalColor() {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => AppColors.surfaceVariant,
    };
  }

  String _getSubtitle() {
    return switch (displayType) {
      TopProductDisplayType.quantity =>
        '${CurrencyFormatter.format(product.totalRevenue)} pendapatan',
      TopProductDisplayType.revenue =>
        '${product.quantitySold} terjual',
      TopProductDisplayType.profit =>
        '${CurrencyFormatter.format(product.totalRevenue)} pendapatan',
    };
  }

  String _getValue() {
    return switch (displayType) {
      TopProductDisplayType.quantity => '${product.quantitySold}',
      TopProductDisplayType.revenue =>
        CurrencyFormatter.format(product.totalRevenue),
      TopProductDisplayType.profit =>
        CurrencyFormatter.format(product.totalProfit),
    };
  }

  Color _getValueColor() {
    return switch (displayType) {
      TopProductDisplayType.quantity => AppColors.primary,
      TopProductDisplayType.revenue => AppColors.primary,
      TopProductDisplayType.profit => AppColors.success,
    };
  }
}

/// Display type for top product tile
enum TopProductDisplayType {
  quantity,
  revenue,
  profit,
}
