import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/components/button/modern_button.dart';
import '../../../../shared/modern/components/card/modern_card.dart';
import '../../../../shared/modern/components/data_display/modern_list_tile.dart';
import '../../../../shared/modern/components/feedback/modern_dialog.dart';
import '../../../../shared/modern/components/feedback/modern_loading.dart';
import '../../../../shared/modern/components/feedback/modern_toast.dart';
import '../../../../shared/modern/utils/modern_variants.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/update_product.dart';
import '../providers/product_selection_provider.dart';
import '../providers/products_provider.dart';

/// Widget displayed when products are selected for bulk actions
class ProductBulkActionsBar extends ConsumerStatefulWidget {
  const ProductBulkActionsBar({super.key});

  @override
  ConsumerState<ProductBulkActionsBar> createState() =>
      _ProductBulkActionsBarState();
}

class _ProductBulkActionsBarState extends ConsumerState<ProductBulkActionsBar> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final selectionCount = ref.watch(selectionCountProvider);

    if (selectionCount == 0) return const SizedBox.shrink();

    // Measures the bar's own width, not the window.
    final isMobile = context.isCompact;

    return ModernCard.outlined(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing12,
      ),
      child: Row(
        children: [
          // Close button and selection count
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isLoading
                ? null
                : () => ref
                    .read(productSelectionProvider.notifier)
                    .clearSelection(),
            iconSize: AppDimensions.iconMedium,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: AppDimensions.minTouchTarget,
              minHeight: AppDimensions.minTouchTarget,
            ),
            color: AppColors.textSecondary,
            tooltip: 'Batal pilih',
          ),
          const SizedBox(width: AppDimensions.spacing4),
          Expanded(
            child: Text(
              isMobile ? '$selectionCount dipilih' : '$selectionCount produk dipilih',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Bulk action buttons
          if (_isLoading)
            const ModernLoading.medium()
          else ...[
            // On mobile, show icon-only buttons
            if (isMobile) ...[
              IconButton(
                onPressed: () => _handleUpdateStatus(context),
                icon: const Icon(Icons.toggle_on_outlined),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                color: AppColors.primary,
                tooltip: 'Ubah Status',
              ),
              IconButton(
                onPressed: () => _handleBulkDelete(context),
                icon: const Icon(Icons.delete_outline),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                color: AppColors.error,
                tooltip: 'Hapus',
              ),
            ] else ...[
              ModernButton.secondary(
                onPressed: () => _handleUpdateStatus(context),
                size: ModernSize.small,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.toggle_on_outlined, size: 18),
                    SizedBox(width: AppDimensions.spacing4),
                    Text('Ubah Status'),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              ModernButton.destructive(
                onPressed: () => _handleBulkDelete(context),
                size: ModernSize.small,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: AppDimensions.spacing4),
                    Text('Hapus'),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _handleUpdateStatus(BuildContext context) async {
    final selectedProducts = ref.read(selectedProductsProvider);

    final result = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
      ),
      builder: (context) => _StatusSelectionSheet(
        productCount: selectedProducts.length,
      ),
    );

    if (result != null && mounted) {
      await _executeBulkStatusUpdate(selectedProducts, result);
    }
  }

  Future<void> _handleBulkDelete(BuildContext context) async {
    final selectedProducts = ref.read(selectedProductsProvider);
    final count = selectedProducts.length;

    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Hapus $count Produk?',
      message: 'Produk yang dihapus tidak dapat dikembalikan.',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      await _executeBulkDelete(selectedProducts);
    }
  }

  Future<void> _executeBulkStatusUpdate(
    List<Product> products,
    bool isActive,
  ) async {
    setState(() => _isLoading = true);

    final updateProduct = getIt<UpdateProduct>();

    try {
      for (final product in products) {
        final updatedProduct = product.copyWith(isActive: isActive);
        await updateProduct(updatedProduct);
      }

      ref.read(productSelectionProvider.notifier).clearSelection();
      ref.invalidate(productsProvider);

      if (mounted) {
        ModernToast.success(
          context,
          '${products.length} produk berhasil diperbarui',
        );
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(context, 'Gagal memperbarui produk: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executeBulkDelete(List<Product> products) async {
    setState(() => _isLoading = true);

    final deleteProduct = getIt<DeleteProduct>();

    try {
      for (final product in products) {
        await deleteProduct(DeleteProductParams(id: product.id));
      }

      ref.read(productSelectionProvider.notifier).clearSelection();
      ref.invalidate(productsProvider);

      if (mounted) {
        ModernToast.success(
          context,
          '${products.length} produk berhasil dihapus',
        );
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(context, 'Gagal menghapus produk: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Bottom sheet for selecting status
class _StatusSelectionSheet extends StatelessWidget {
  const _StatusSelectionSheet({
    required this.productCount,
  });

  final int productCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Text(
              'Ubah Status $productCount Produk',
              style: AppTextStyles.h4,
            ),
            const SizedBox(height: AppDimensions.spacing16),
            // Options
            ModernCard.outlined(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ModernListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                      ),
                    ),
                    title: const Text('Aktif (Tersedia)'),
                    subtitle: const Text('Produk dapat dijual'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  const Divider(height: 1),
                  ModernListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.cancel,
                        color: AppColors.error,
                      ),
                    ),
                    title: const Text('Nonaktif (Habis)'),
                    subtitle: const Text('Produk tidak ditampilkan'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
          ],
        ),
      ),
    );
  }
}
