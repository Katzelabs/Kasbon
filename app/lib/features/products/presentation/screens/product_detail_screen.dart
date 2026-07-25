import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../reports/presentation/providers/profit_report_provider.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';
import '../widgets/product_image.dart';
import '../widgets/stock_indicator.dart';

/// Screen displaying detailed information about a product
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
        ref.invalidate(productsProvider);
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
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: productAsync.when(
        data: (product) => _buildContent(context, ref, product, formState),
        loading: () => const Center(child: ModernLoading()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Text('Error: $error'),
              const SizedBox(height: AppDimensions.spacing16),
              ModernButton.primary(
                onPressed: () => ref.invalidate(productProvider(productId)),
                child: const Text('Coba Lagi'),
              ),
            ],
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

    final isTablet = context.isTabletOrDesktop;

    return isTablet
        ? _buildTabletLayout(context, ref, product)
        : _buildMobileLayout(context, ref, product);
  }

  Widget _buildMobileLayout(
      BuildContext context, WidgetRef ref, Product product) {
    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding = context.isMobile
        ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
        : AppDimensions.spacing16;

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
          _buildProductHeaderCard(context, ref, product),
          const SizedBox(height: AppDimensions.spacing16),
          _buildProductImage(context, product),
          const SizedBox(height: AppDimensions.spacing24),
          _buildInfoCard(product),
          const SizedBox(height: AppDimensions.spacing16),
          _buildPricingCard(product),
          const SizedBox(height: AppDimensions.spacing16),
          _buildStockCard(product),
          const SizedBox(height: AppDimensions.spacing16),
          _buildProfitHistoryCard(ref, product),
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
          _buildProductHeaderCard(context, ref, product),
          const SizedBox(height: AppDimensions.spacing24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Image and Info
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildProductImage(context, product),
                    const SizedBox(height: AppDimensions.spacing24),
                    _buildInfoCard(product),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing24),
              // Right column: Pricing, Stock, and Profit History
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildPricingCard(product),
                    const SizedBox(height: AppDimensions.spacing16),
                    _buildStockCard(product),
                    const SizedBox(height: AppDimensions.spacing16),
                    _buildProfitHistoryCard(ref, product),
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

  Widget _buildProductImage(BuildContext context, Product product) {
    final isTablet = context.isTabletOrDesktop;
    final imageSize = isTablet ? 200.0 : 120.0;

    return Center(
      child: ProductImage(
        imagePath: product.imageUrl,
        size: imageSize,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        placeholderIconSize: imageSize * 0.4,
      ),
    );
  }

  Widget _buildInfoCard(Product product) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Produk',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          _buildInfoRow('Nama', product.name),
          _buildInfoRow('SKU', product.sku),
          _buildInfoRow('Satuan', product.unit),
          if (product.description != null && product.description!.isNotEmpty)
            _buildInfoRow('Deskripsi', product.description!),
          if (product.barcode != null && product.barcode!.isNotEmpty)
            _buildInfoRow('Barcode', product.barcode!),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Product product) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harga & Keuntungan',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          _buildInfoRow(
              'Harga Modal', CurrencyFormatter.format(product.costPrice)),
          _buildInfoRow(
              'Harga Jual', CurrencyFormatter.format(product.sellingPrice)),
          const Divider(height: AppDimensions.spacing24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Keuntungan', style: AppTextStyles.labelLarge),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(product.profit),
                    style: AppTextStyles.priceMedium.copyWith(
                      color: product.profit >= 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  Text(
                    '${product.profitMargin.toStringAsFixed(1)}%',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(Product product) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stok',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              StockIndicator(
                stock: product.stock,
                minStock: product.minStock,
                showIcon: true,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          _buildInfoRow('Stok Saat Ini', '${product.stock} ${product.unit}'),
          _buildInfoRow('Minimal Stok', '${product.minStock} ${product.unit}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing16),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeaderCard(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name, style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            product.sku,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) {
    final isTablet = context.isTabletOrDesktop;

    final editButton = ModernButton.secondary(
      onPressed: () => context.push('/products/${product.id}/edit'),
      leadingIcon: Icons.edit_outlined,
      fullWidth: true,
      child: const Text('Edit Produk'),
    );

    final deleteButton = ModernButton.destructive(
      onPressed: () => _showDeleteConfirmation(context, ref, product),
      leadingIcon: Icons.delete_outline,
      fullWidth: true,
      child: const Text('Hapus Produk'),
    );

    if (isTablet) {
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

  Widget _buildProfitHistoryCard(WidgetRef ref, Product product) {
    final profitabilityAsync =
        ref.watch(productProfitabilityProvider(product.id));

    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Riwayat Penjualan',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          profitabilityAsync.when(
            data: (profitability) => Column(
              children: [
                _buildInfoRow(
                  'Total Terjual',
                  '${profitability.totalSold} ${product.unit}',
                ),
                _buildInfoRow(
                  'Total Laba',
                  CurrencyFormatter.format(profitability.totalProfit),
                ),
                if (profitability.totalSold > 0)
                  _buildInfoRow(
                    'Margin Rata-rata',
                    '${profitability.averageMargin.toStringAsFixed(1)}%',
                  ),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacing16),
                child: ModernLoading.small(),
              ),
            ),
            error: (error, _) => Text(
              'Gagal memuat data',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Hapus Produk?',
      message: 'Apakah Anda yakin ingin menghapus "${product.name}"?',
      confirmLabel: 'Hapus',
      isDestructive: true,
    );

    if (confirmed == true) {
      ref.read(productFormProvider.notifier).deleteProduct(product.id);
    }
  }
}
