import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../reports/presentation/providers/profit_report_provider.dart';
import '../../domain/entities/product.dart';
import 'product_image.dart';
import 'profit_margin_summary.dart';
import 'stock_indicator.dart';

/// The cards a product's detail is made of, independent of what shows them.
///
/// Two presentations use these: [ProductDetailScreen], which is the whole
/// screen on a narrow window, and [ProductDetailPanel], which is docked beside
/// the list on a wide one. They differ in chrome and in where the actions sit,
/// not in what a product looks like - so the cards live here rather than as
/// private methods on whichever one happened to be written first.

/// A label and its value on one line, the shape every card below repeats.
class ProductInfoRow extends StatelessWidget {
  const ProductInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
}

/// The product's photo, sized for the space it is given.
class ProductImagePreview extends StatelessWidget {
  const ProductImagePreview({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final imageSize = context.responsive<double>(compact: 120, expanded: 200);

    return Center(
      child: ProductImage(
        imagePath: product.imageUrl,
        size: imageSize,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        placeholderIconSize: imageSize * 0.4,
      ),
    );
  }
}

/// Name, SKU, unit, and the optional description and barcode.
class ProductInfoCard extends StatelessWidget {
  const ProductInfoCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Informasi Produk'),
          const SizedBox(height: AppDimensions.spacing12),
          ProductInfoRow(label: 'Nama', value: product.name),
          ProductInfoRow(label: 'SKU', value: product.sku),
          ProductInfoRow(label: 'Satuan', value: product.unit),
          if (product.description != null && product.description!.isNotEmpty)
            ProductInfoRow(label: 'Deskripsi', value: product.description!),
          if (product.barcode != null && product.barcode!.isNotEmpty)
            ProductInfoRow(label: 'Barcode', value: product.barcode!),
        ],
      ),
    );
  }
}

/// Cost, selling price and the margin between them.
class ProductPricingCard extends StatelessWidget {
  const ProductPricingCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Harga & Keuntungan'),
          const SizedBox(height: AppDimensions.spacing12),
          ProductInfoRow(
            label: 'Harga Modal',
            value: CurrencyFormatter.format(product.costPrice),
          ),
          ProductInfoRow(
            label: 'Harga Jual',
            value: CurrencyFormatter.format(product.sellingPrice),
          ),
          const Divider(height: AppDimensions.spacing24),
          ProfitMarginSummary(
            costPrice: product.costPrice,
            sellingPrice: product.sellingPrice,
          ),
        ],
      ),
    );
  }
}

/// Current stock against its minimum.
class ProductStockCard extends StatelessWidget {
  const ProductStockCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel('Stok'),
              StockIndicator(
                stock: product.stock,
                minStock: product.minStock,
                showIcon: true,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          ProductInfoRow(
            label: 'Stok Saat Ini',
            value: '${product.stock} ${product.unit}',
          ),
          ProductInfoRow(
            label: 'Minimal Stok',
            value: '${product.minStock} ${product.unit}',
          ),
        ],
      ),
    );
  }
}

/// How much of this product has sold, and what it earned.
class ProductProfitHistoryCard extends ConsumerWidget {
  const ProductProfitHistoryCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitabilityAsync =
        ref.watch(productProfitabilityProvider(product.id));

    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: AppColors.success,
              ),
              SizedBox(width: AppDimensions.spacing8),
              _SectionLabel('Riwayat Penjualan'),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          profitabilityAsync.when(
            data: (profitability) => Column(
              children: [
                ProductInfoRow(
                  label: 'Total Terjual',
                  value: '${profitability.totalSold} ${product.unit}',
                ),
                ProductInfoRow(
                  label: 'Total Laba',
                  value: CurrencyFormatter.format(profitability.totalProfit),
                ),
                if (profitability.totalSold > 0)
                  ProductInfoRow(
                    label: 'Margin Rata-rata',
                    value:
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
}

/// The product's name and SKU as a card, for the presentations that lead with
/// one rather than putting the name in their header.
class ProductHeaderCard extends StatelessWidget {
  const ProductHeaderCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
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
}

/// Asks before deleting, then deletes.
///
/// Shared so the screen and the panel ask the same question in the same words.
Future<void> confirmDeleteProduct(
  BuildContext context,
  WidgetRef ref,
  Product product,
  void Function(String id) onConfirmed,
) async {
  final confirmed = await ModernDialog.confirm(
    context,
    title: 'Hapus Produk?',
    message: 'Apakah Anda yakin ingin menghapus "${product.name}"?',
    confirmLabel: 'Hapus',
    isDestructive: true,
  );

  if (confirmed == true) {
    onConfirmed(product.id);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }
}
