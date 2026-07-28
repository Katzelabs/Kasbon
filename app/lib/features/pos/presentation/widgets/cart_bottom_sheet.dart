import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/cart_operation_result.dart';
import '../providers/cart_provider.dart';
import 'cart_item_tile.dart';
import 'payment_dialog.dart';

/// Bottom sheet for displaying and managing cart items
///
/// Shows list of cart items with quantity controls and total.
/// Provides "BAYAR" button to proceed to payment.
class CartBottomSheet extends ConsumerWidget {
  const CartBottomSheet({
    super.key,
    this.scrollController,
  });

  final ScrollController? scrollController;

  /// Show the cart
  ///
  /// A draggable bottom sheet on a phone, a right-edge side sheet on a desktop
  /// window. `showAdaptiveDraggable` rather than `showAdaptive` because the
  /// body below is a list with a pinned footer under it - an `Expanded` inside
  /// a scroll view has no height to expand into.
  static Future<void> show(BuildContext context) {
    return ModernBottomSheet.showAdaptiveDraggable<void>(
      context,
      builder: (context, scrollController) => CartBottomSheet(
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final itemCount = ref.watch(cartItemCountProvider);
    final total = ref.watch(cartTotalProvider);
    final hasStockWarning = ref.watch(cartHasStockWarningProvider);

    return Column(
      children: [
        // Handle bar. A drag affordance, so it appears only where there is a
        // drag: the side-sheet form passes no scroll controller and does not
        // move.
        if (scrollController != null)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppDimensions.spacing12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        // Header
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Keranjang',
                style: AppTextStyles.h4,
              ),
              Row(
                children: [
                  Text(
                    '$itemCount item',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (cart.isNotEmpty) ...[
                    const SizedBox(width: AppDimensions.spacing12),
                    ModernButton.text(
                      onPressed: () => _confirmClearCart(context, ref),
                      size: ModernSize.small,
                      child: Text(
                        'Hapus Semua',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const ModernDivider(),
        // Cart items list
        Expanded(
          child: cart.isEmpty
              ? _buildEmptyCart()
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimensions.spacing16),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.spacing12),
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    return CartItemTile(
                      item: item,
                      onQuantityChanged: (qty) {
                        final result = ref
                            .read(cartProvider.notifier)
                            .updateQuantity(item.product.id, qty);

                        if (result.result == CartOperationResult.exceedsStock) {
                          ModernToast.warning(
                            context,
                            'Stok maksimal ${result.availableStock} ${result.unit}',
                          );
                        }
                      },
                      onRemove: () {
                        ref
                            .read(cartProvider.notifier)
                            .removeProduct(item.product.id);
                      },
                    );
                  },
                ),
        ),
        // Stock warning
        if (hasStockWarning)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
              vertical: AppDimensions.spacing8,
            ),
            color: AppColors.warningLight,
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: AppDimensions.iconMedium,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'Beberapa item melebihi stok yang tersedia',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Footer with total and pay button
        _buildFooter(context, ref, total, cart.isNotEmpty),
      ],
    );
  }

  /// Show confirmation dialog before clearing cart
  Future<void> _confirmClearCart(BuildContext context, WidgetRef ref) async {
    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Hapus Semua Item?',
      message: 'Semua item di keranjang akan dihapus.',
      confirmLabel: 'Hapus Semua',
      cancelLabel: 'Batal',
      isDestructive: true,
    );

    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            'Keranjang Kosong',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Pilih produk untuk menambahkan ke keranjang',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    double total,
    bool hasItems,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: AppShadows.up,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Total row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(total),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            // Pay button
            ModernButton.primary(
              onPressed: hasItems
                  ? () async {
                      // Close bottom sheet first
                      Navigator.pop(context);
                      // Show payment dialog
                      final result = await PaymentDialog.show(context);
                      if (result == true) {
                        // Payment was successful - navigation handled by dialog
                      }
                    }
                  : null,
              fullWidth: true,
              size: ModernSize.large,
              child: const Text('BAYAR'),
            ),
          ],
        ),
      ),
    );
  }
}
