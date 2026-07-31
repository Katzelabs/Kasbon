import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/product.dart';

/// "Keuntungan Rp 3.000 / 37,5%" for a cost and a selling price.
///
/// Takes two doubles rather than a [Product] so it can sit under a form that
/// is being typed into, where no product exists yet. Showing the margin as the
/// prices are entered is the point: cost price is the field that makes KASBON
/// different from a cash drawer, and this is where the user finds out why they
/// were asked for it.
///
/// The arithmetic comes from [Product.profitOf] and [Product.profitMarginOf],
/// the same pair the entity's own getters use, so the figure under the form and
/// the figure on the detail screen cannot drift. Margin is over *cost*, not
/// over revenue.
class ProfitMarginSummary extends StatelessWidget {
  const ProfitMarginSummary({
    super.key,
    required this.costPrice,
    required this.sellingPrice,
    this.label = 'Keuntungan',
  });

  final double costPrice;
  final double sellingPrice;
  final String label;

  @override
  Widget build(BuildContext context) {
    final profit = Product.profitOf(costPrice, sellingPrice);
    final margin = Product.profitMarginOf(costPrice, sellingPrice);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(profit),
              style: AppTextStyles.priceMedium.copyWith(
                color: profit >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
            Text(
              '${margin.toStringAsFixed(1)}%',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
