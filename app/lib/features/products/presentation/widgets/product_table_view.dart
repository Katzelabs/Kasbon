import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/components/card/modern_card.dart';
import '../../../../shared/modern/components/data_display/modern_badge.dart';
import '../../../../shared/modern/components/data_display/modern_data_table.dart';
import '../../../../shared/modern/components/data_display/modern_table_column.dart';
import '../../domain/entities/product.dart';
import '../providers/product_selection_provider.dart';
import 'product_image.dart';

/// Table view widget for product list
/// Displays products in a tabular format with selection support
class ProductTableView extends ConsumerStatefulWidget {
  const ProductTableView({
    super.key,
    required this.products,
  });

  final List<Product> products;

  @override
  ConsumerState<ProductTableView> createState() => _ProductTableViewState();
}

class _ProductTableViewState extends ConsumerState<ProductTableView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(productSelectionProvider);

    // One table, two shapes. The compact form used to be a second
    // ModernDataTable with its own narrower columns and a horizontal scroll
    // controller; ModernDataTable.narrowBuilder absorbs it, so the two can no
    // longer drift apart - and the card list shows every field at once rather
    // than hiding half of them behind a sideways drag.
    return ModernDataTable<Product>(
      columns: _buildColumns(),
      items: widget.products,
      idGetter: (product) => product.id,
      selectedIds: selectedIds,
      shrinkWrap: true, // Fit table to content, no vertical scrolling
      horizontalScrollController: _scrollController,
      narrowBuilder: (context, product, isSelected) => _ProductNarrowCard(
        product: product,
        isSelected: isSelected,
        onSelectionChanged: (selected) => _setSelected(product.id, selected),
      ),
      onSelectionChanged: _setSelected,
      onSelectAll: (selectAll) {
        if (selectAll) {
          ref
              .read(productSelectionProvider.notifier)
              .selectAll(widget.products.map((p) => p.id).toList());
        } else {
          ref.read(productSelectionProvider.notifier).clearSelection();
        }
      },
      onRowTap: (product) {
        context.go(AppRoutes.productDetailPath(product.id));
      },
      rowHeight: 64.0,
      headerHeight: 48.0,
    );
  }

  void _setSelected(String id, bool selected) {
    final notifier = ref.read(productSelectionProvider.notifier);
    if (selected) {
      notifier.select(id);
    } else {
      notifier.deselect(id);
    }
  }

  List<ModernTableColumn<Product>> _buildColumns() {
    return [
      // Image column
      ModernTableColumnFactories.image<Product>(
        id: 'image',
        size: 48,
        imageBuilder: _buildProductImage,
      ),
      // Name column
      ModernTableColumn<Product>(
        id: 'name',
        header: Text(
          'Nama Produk',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        flex: 2,
        minWidth: 150,
        cellBuilder: (product) => Text(
          product.name,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // SKU column
      ModernTableColumn<Product>(
        id: 'sku',
        header: Text(
          'SKU',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        width: 120,
        cellBuilder: (product) => Text(
          product.sku,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontFeatures: AppTextStyles.tabularFigures,
          ),
        ),
      ),
      // Price column
      ModernTableColumn<Product>(
        id: 'price',
        header: Text(
          'Harga',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        width: 130,
        alignment: Alignment.centerRight,
        cellBuilder: (product) => Text(
          CurrencyFormatter.format(product.sellingPrice),
          style: AppTextStyles.priceSmall.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      // Stock column
      ModernTableColumn<Product>(
        id: 'stock',
        header: Text(
          'Stok',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        width: 80,
        alignment: Alignment.center,
        cellBuilder: (product) => Text(
          '${product.stock}',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: _ProductTableViewColors.stock(product),
          ),
        ),
      ),
      // Status column
      ModernTableColumn<Product>(
        id: 'status',
        header: Text(
          'Status',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        width: 100,
        alignment: Alignment.center,
        cellBuilder: (product) => _ProductTableViewColors.badge(product),
      ),
      // Actions column
      ModernTableColumn<Product>(
        id: 'actions',
        header: const SizedBox.shrink(),
        width: 56,
        alignment: Alignment.center,
        cellBuilder: (product) => _buildActionButtons(context, product),
      ),
    ];
  }

  /// The photo cell, or null for a product without one - which lets the column
  /// place its own placeholder rather than this deciding twice.
  Widget? _buildProductImage(Product product) {
    final reference = product.imageUrl;
    if (reference == null || reference.isEmpty) return null;

    return ProductImage(
      imagePath: reference,
      size: 48,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      placeholderIconSize: 24,
    );
  }

  Widget _buildActionButtons(BuildContext context, Product product) {
    return SizedBox(
      width: AppDimensions.minTouchTarget,
      height: AppDimensions.minTouchTarget,
      child: IconButton(
        icon: const Icon(Icons.edit_outlined),
        iconSize: AppDimensions.iconMedium,
        color: AppColors.textSecondary,
        onPressed: () {
          context.go(AppRoutes.productEditPath(product.id));
        },
        tooltip: 'Edit',
        constraints: const BoxConstraints(
          minWidth: AppDimensions.minTouchTarget,
          minHeight: AppDimensions.minTouchTarget,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// The compact-tier row: everything the table columns show, stacked to fit a
/// phone.
///
/// Replaces the horizontally-scrolling table this file used to render below
/// 600dp, which fitted by dropping the SKU column and shortening every badge
/// label to something like "Off" - and still needed a sideways drag to reach
/// the edit button.
class _ProductNarrowCard extends StatelessWidget {
  const _ProductNarrowCard({
    required this.product,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  final Product product;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      borderColor: isSelected ? AppColors.primary : AppColors.border,
      color: isSelected ? AppColors.primaryContainer : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) => onSelectionChanged(value ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
          ),
          ProductImage(
            imagePath: product.imageUrl,
            size: 48,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            placeholderIconSize: 24,
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spacing2),
                Text(
                  product.sku,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontFeatures: AppTextStyles.tabularFigures,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Row(
                  children: [
                    Text(
                      CurrencyFormatter.format(product.sellingPrice),
                      style: AppTextStyles.priceSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Text(
                      'Stok ${product.stock}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _ProductTableViewColors.stock(product),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ProductTableViewColors.badge(product),
              const SizedBox(height: AppDimensions.spacing4),
              SizedBox(
                width: AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: AppDimensions.iconMedium,
                  color: AppColors.textSecondary,
                  onPressed: () =>
                      context.go(AppRoutes.productEditPath(product.id)),
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Presentation rules shared by the table cells and the compact card, so the
/// two forms of the same row cannot disagree about what "low stock" looks like.
class _ProductTableViewColors {
  _ProductTableViewColors._();

  static Color stock(Product product) {
    if (product.isOutOfStock) return AppColors.error;
    if (product.isLowStock) return AppColors.warning;
    return AppColors.textPrimary;
  }

  static Widget badge(Product product) {
    if (!product.isActive) return const ModernBadge.neutral(label: 'Nonaktif');
    if (product.isOutOfStock) return const ModernBadge.error(label: 'Habis');
    if (product.isLowStock) return const ModernBadge.warning(label: 'Rendah');
    return const ModernBadge.success(label: 'Aktif');
  }
}
