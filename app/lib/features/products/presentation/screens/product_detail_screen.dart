import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';
import '../widgets/product_detail_sections.dart';

/// Screen displaying detailed information about a product.
///
/// The full-screen presentation, reached by drilling into a product on a window
/// too narrow to split. At `expanded` and up the list shows a
/// [ProductDetailPanel] beside itself instead and this route renders nothing -
/// see `MasterDetailScaffold`. The cards both use are shared, in
/// `product_detail_sections.dart`.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));
    final formState = ref.watch(productFormProvider);

    // Listen for delete success
    ref.listen(productFormProvider, (previous, next) {
      if (next.isSuccess && previous?.isLoading == true) {
        ref.invalidate(paginatedProductsProvider);
        ModernToast.success(context, 'Produk berhasil dihapus');
        context.pop();
      } else if (next.errorMessage != null) {
        ModernToast.error(context, next.errorMessage!);
      }
    });

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Detail Produk',
        onBack: () => context.pop(),
      ),
      body: productAsync.when(
        data: (product) => _buildContent(context, ref, product, formState),
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

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Product product,
    ProductFormState formState,
  ) {
    if (formState.isLoading) {
      return const Center(child: ModernLoading());
    }

    // The space this screen has, not the window.
    final isWide = context.isAtLeast(Breakpoint.expanded);

    return isWide
        ? _buildTabletLayout(context, ref, product)
        : _buildMobileLayout(context, ref, product);
  }

  Widget _buildMobileLayout(
      BuildContext context, WidgetRef ref, Product product) {
    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding = AppDimensions.spacing16 + context.shellBottomInset;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppDimensions.spacing16,
        right: AppDimensions.spacing16,
        top: AppDimensions.spacing16,
        bottom: bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductHeaderCard(product: product),
          const SizedBox(height: AppDimensions.spacing16),
          ProductImagePreview(product: product),
          const SizedBox(height: AppDimensions.spacing24),
          ProductInfoCard(product: product),
          const SizedBox(height: AppDimensions.spacing16),
          ProductPricingCard(product: product),
          const SizedBox(height: AppDimensions.spacing16),
          ProductStockCard(product: product),
          const SizedBox(height: AppDimensions.spacing16),
          ProductProfitHistoryCard(product: product),
          const SizedBox(height: AppDimensions.spacing24),
          _buildActionButtons(context, ref, product),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(
      BuildContext context, WidgetRef ref, Product product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductHeaderCard(product: product),
          const SizedBox(height: AppDimensions.spacing24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Image and Info
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    ProductImagePreview(product: product),
                    const SizedBox(height: AppDimensions.spacing24),
                    ProductInfoCard(product: product),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing24),
              // Right column: Pricing, Stock, and Profit History
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    ProductPricingCard(product: product),
                    const SizedBox(height: AppDimensions.spacing16),
                    ProductStockCard(product: product),
                    const SizedBox(height: AppDimensions.spacing16),
                    ProductProfitHistoryCard(product: product),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          _buildActionButtons(context, ref, product),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) {
    final isWide = context.isAtLeast(Breakpoint.expanded);

    final editButton = ModernButton.secondary(
      onPressed: () => context.go(AppRoutes.productEditPath(product.id)),
      leadingIcon: Icons.edit_outlined,
      fullWidth: true,
      child: const Text('Edit Produk'),
    );

    final deleteButton = ModernButton.destructive(
      onPressed: () => confirmDeleteProduct(
        context,
        ref,
        product,
        (id) => ref.read(productFormProvider.notifier).deleteProduct(id),
      ),
      leadingIcon: Icons.delete_outline,
      fullWidth: true,
      child: const Text('Hapus Produk'),
    );

    if (isWide) {
      // Tablet: 2 columns, aligned to end/right
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(width: 180, child: editButton),
          const SizedBox(width: AppDimensions.spacing12),
          SizedBox(width: 180, child: deleteButton),
        ],
      );
    } else {
      // Mobile: Full-width row
      return Row(
        children: [
          Expanded(child: editButton),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(child: deleteButton),
        ],
      );
    }
  }
}
