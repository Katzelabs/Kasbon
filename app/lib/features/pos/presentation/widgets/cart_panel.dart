import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_operation_result.dart';
import '../providers/cart_provider.dart';
import 'cart_item_tile.dart';
import 'payment_dialog.dart';

/// Where a [CartPanel] is mounted, and therefore what chrome it wears.
///
/// This is the *only* axis on which the two presentations differ. Everything
/// else - the item list, the stock warning, the total, the BAYAR button, the
/// clear-cart confirmation - is identical, which is why they now share a
/// widget instead of two near-identical 120-line builds that drifted apart.
enum CartPanelChrome {
  /// Docked beside the product grid in the POS split view.
  ///
  /// Carries a close control, no drag handle, and no bottom safe-area inset -
  /// the shell owns that edge, and adding one here inset the footer twice.
  sidebar,

  /// Presented as a modal: a draggable bottom sheet on a narrow window, a
  /// right-edge side sheet on a wide one.
  ///
  /// Checkout pops the sheet before opening the payment dialog, which the
  /// docked form must not do - there is no route to pop.
  sheet,
}

/// The cart, in whichever chrome the current layout calls for.
///
/// ## Why this exists
///
/// `pos_screen` and `cart_bottom_sheet` each carried their own copy of the
/// header, empty state, item list, stock-warning strip and footer. Any change
/// to the cart had to be made twice and verified at two widths, and the copies
/// had already diverged: one said `(3)` where the other said `3 item`, and the
/// clear-cart confirmation existed twice, word for word.
///
/// The layout work in RESP_06 would have made that a third variant. So the
/// extraction lands first.
class CartPanel extends ConsumerWidget {
  const CartPanel({
    super.key,
    required this.chrome,
    this.scrollController,
    this.onClose,
  });

  /// The docked form, with a close control.
  const CartPanel.sidebar({
    super.key,
    required VoidCallback this.onClose,
  })  : chrome = CartPanelChrome.sidebar,
        scrollController = null;

  /// The modal form. Pass the sheet's [scrollController] when there is one;
  /// the side-sheet presentation does not scroll as a whole and passes none.
  const CartPanel.sheet({
    super.key,
    this.scrollController,
  })  : chrome = CartPanelChrome.sheet,
        onClose = null;

  /// The drag affordance, present only on the draggable sheet.
  static const Key dragHandleKey = Key('cart-panel-drag-handle');

  /// The collapse control, present only on the docked panel.
  static const Key closeButtonKey = Key('cart-panel-close');

  final CartPanelChrome chrome;

  /// Drives the drag-to-dismiss gesture on a bottom sheet.
  final ScrollController? scrollController;

  /// Collapses the docked panel. Null in the sheet, which dismisses itself.
  final VoidCallback? onClose;

  bool get _isSheet => chrome == CartPanelChrome.sheet;

  /// A drag affordance belongs only where there is a drag. The side sheet is
  /// the same chrome without a scroll controller, and does not move.
  bool get _showsDragHandle => _isSheet && scrollController != null;

  /// Confirms, then empties the cart.
  ///
  /// Static because `pos_screen` binds the same action to Ctrl+Backspace via
  /// [PosShortcuts], and a keyboard clear must ask the same question a tapped
  /// one does.
  static Future<void> confirmClearCart(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final itemCount = ref.watch(cartItemCountProvider);
    final total = ref.watch(cartTotalProvider);
    final hasStockWarning = ref.watch(cartHasStockWarningProvider);

    return Column(
      children: [
        if (_showsDragHandle) const _DragHandle(key: dragHandleKey),
        _buildHeader(context, ref,
            itemCount: itemCount, hasItems: cart.isNotEmpty),
        const ModernDivider(),
        Expanded(
          child: cart.isEmpty
              ? const _EmptyCart()
              : _buildItems(context, ref, cart),
        ),
        if (hasStockWarning) const _StockWarning(),
        _buildFooter(context, total: total, hasItems: cart.isNotEmpty),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref, {
    required int itemCount,
    required bool hasItems,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.spacing16,
        // The close button carries its own touch-target padding, so the panel
        // keeps its optical margin only when there is no button to supply it.
        right:
            onClose == null ? AppDimensions.spacing16 : AppDimensions.spacing8,
        top: AppDimensions.spacing12,
        bottom: AppDimensions.spacing12,
      ),
      child: Row(
        children: [
          const Text('Keranjang', style: AppTextStyles.h4),
          const SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: Text(
              '$itemCount item',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasItems)
            ModernButton.text(
              onPressed: () => confirmClearCart(context, ref),
              size: ModernSize.small,
              child: Text(
                'Hapus Semua',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          if (onClose != null)
            IconButton(
              key: closeButtonKey,
              onPressed: onClose,
              icon: const Icon(Icons.close),
              iconSize: AppDimensions.iconMedium,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppDimensions.minTouchTarget,
                minHeight: AppDimensions.minTouchTarget,
              ),
              tooltip: 'Tutup keranjang',
            ),
        ],
      ),
    );
  }

  Widget _buildItems(BuildContext context, WidgetRef ref, List<CartItem> cart) {
    return ListView.separated(
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
            ref.read(cartProvider.notifier).removeProduct(item.product.id);
          },
        );
      },
    );
  }

  Widget _buildFooter(
    BuildContext context, {
    required double total,
    required bool hasItems,
  }) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
              style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing16),
        ModernButton.primary(
          onPressed: hasItems ? () => _checkout(context) : null,
          fullWidth: true,
          size: ModernSize.large,
          child: const Text('BAYAR'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.up,
      ),
      // Only the modal reaches the bottom edge of the window. The docked panel
      // sits inside the shell, which has already inset itself.
      child: _isSheet ? SafeArea(child: body) : body,
    );
  }

  Future<void> _checkout(BuildContext context) async {
    // The sheet gets out of the way first: leaving it up would stack a dialog
    // on a sheet, and the success route it pushes would land behind both.
    if (_isSheet) Navigator.pop(context);
    await PaymentDialog.show(context);
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: AppDimensions.spacing12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
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
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            child: Text(
              'Pilih produk untuk menambahkan ke keranjang',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockWarning extends StatelessWidget {
  const _StockWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
