import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/cart_provider.dart';
import 'cart_bottom_sheet.dart';

/// Fixed bottom bar showing cart summary
///
/// Displays item count and total, opens cart bottom sheet when tapped.
/// Only visible when there are items in cart.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(cartItemCountProvider);
    final total = ref.watch(cartTotalProvider);
    final isEmpty = ref.watch(cartIsEmptyProvider);

    if (isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacing16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        color: AppColors.primary,
        child: InkWell(
          onTap: () => CartBottomSheet.show(context),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing20,
              vertical: AppDimensions.spacing16,
            ),
            child: Row(
              children: [
                // Cart icon and item count
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                    ),
                    const SizedBox(width: AppDimensions.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing8,
                        vertical: AppDimensions.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusRound),
                      ),
                      child: Text(
                        '$itemCount item',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Total
                Text(
                  CurrencyFormatter.format(total),
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: AppDimensions.iconSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
