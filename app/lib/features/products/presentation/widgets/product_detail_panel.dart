import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';
import 'product_detail_sections.dart';

/// A product's detail, docked beside the list at desktop width.
///
/// ## Why not just render `ProductDetailScreen` in the pane
///
/// It is a `Scaffold` with an app bar, and a pane is not a screen. Dropping one
/// into the other gave a second header bar inside the window's content area,
/// action buttons that scrolled away with the page, and a back affordance for a
/// stack the pane is not part of.
///
/// So this follows the shape `CartPanel` established for the POS split view:
/// a header row with a close control, a scrolling body, and a footer pinned to
/// the bottom edge where the actions stay reachable however long the content
/// gets. The cards in the body are the same ones the full screen uses - see
/// `product_detail_sections.dart` - so the two cannot drift.
class ProductDetailPanel extends ConsumerWidget {
  const ProductDetailPanel({
    super.key,
    required this.productId,
    required this.onClose,
  });

  final String productId;

  /// Collapses the panel, returning the URL to the list.
  final VoidCallback onClose;

  /// The collapse control, for tests and for anything driving the panel.
  static const Key closeButtonKey = Key('product-detail-panel-close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));

    // Deleting is the one action that ends the panel's reason to exist.
    ref.listen(productFormProvider, (previous, next) {
      if (next.isSuccess && previous?.isLoading == true) {
        ref.invalidate(productsProvider);
        ModernToast.success(context, 'Produk berhasil dihapus');
        onClose();
      } else if (next.errorMessage != null) {
        ModernToast.error(context, next.errorMessage!);
      }
    });

    return ColoredBox(
      color: AppColors.surface,
      child: productAsync.when(
        data: (product) => _buildPanel(context, ref, product),
        loading: () => const Center(child: ModernLoading()),
        error: (error, _) => Center(
          child: ModernErrorState.generic(
            message: 'Gagal memuat produk. $error',
            onRetry: () => ref.invalidate(productProvider(productId)),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, WidgetRef ref, Product product) {
    final isDeleting = ref.watch(productFormProvider).isLoading;

    return Column(
      children: [
        _buildHeader(context, product),
        const ModernDivider(),
        Expanded(child: _buildBody(product)),
        _buildFooter(context, ref, product, isDeleting: isDeleting),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Product product) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.spacing16,
        // The close button carries its own touch-target padding, so the panel
        // does not add an optical margin the button already supplies.
        right: AppDimensions.spacing8,
        top: AppDimensions.spacing12,
        bottom: AppDimensions.spacing12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product.sku,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
            tooltip: 'Tutup detail',
          ),
        ],
      ),
    );
  }

  /// One column, always.
  ///
  /// The screen's two-column fork exists because a full-width tablet leaves the
  /// cards stretched and short; a pane is already the narrow half of a split
  /// and splitting it again would give two columns of ~250dp.
  Widget _buildBody(Product product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductImagePreview(product: product),
          const SizedBox(height: AppDimensions.spacing24),
          ProductInfoCard(product: product),
          const SizedBox(height: AppDimensions.spacing16),
          ProductPricingCard(product: product),
          const SizedBox(height: AppDimensions.spacing16),
          ProductStockCard(product: product),
          const SizedBox(height: AppDimensions.spacing16),
          ProductProfitHistoryCard(product: product),
        ],
      ),
    );
  }

  /// Pinned, not scrolled with the content: on a tall product the screen's
  /// buttons sat below the fold, and the panel's whole point is that the list
  /// and the actions are both reachable at once.
  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    Product product, {
    required bool isDeleting,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          Expanded(
            child: ModernButton.secondary(
              onPressed: isDeleting
                  ? null
                  : () => context.go(AppRoutes.productEditPath(product.id)),
              leadingIcon: Icons.edit_outlined,
              fullWidth: true,
              child: const Text('Edit'),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: ModernButton.destructive(
              onPressed: isDeleting
                  ? null
                  : () => confirmDeleteProduct(
                        context,
                        ref,
                        product,
                        (id) =>
                            ref.read(productFormProvider.notifier).deleteProduct(id),
                      ),
              leadingIcon: Icons.delete_outline,
              isLoading: isDeleting,
              fullWidth: true,
              child: const Text('Hapus'),
            ),
          ),
        ],
      ),
    );
  }
}
