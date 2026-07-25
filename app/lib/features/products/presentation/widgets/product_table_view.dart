import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // On mobile, use horizontal scrollable table
    if (isMobile) {
      return _buildMobileTable(selectedIds);
    }

    return _buildDesktopTable(selectedIds);
  }

  Widget _buildDesktopTable(Set<String> selectedIds) {
    return ModernDataTable<Product>(
      columns: _buildColumns(false),
      items: widget.products,
      idGetter: (product) => product.id,
      selectedIds: selectedIds,
      shrinkWrap: true, // Fit table to content, no vertical scrolling
      onSelectionChanged: (id, selected) {
        if (selected) {
          ref.read(productSelectionProvider.notifier).select(id);
        } else {
          ref.read(productSelectionProvider.notifier).deselect(id);
        }
      },
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
        context.push('${AppRoutes.products}/${product.id}');
      },
      rowHeight: 64.0,
      headerHeight: 48.0,
    );
  }

  /// Build mobile-optimized table with horizontal scroll
  Widget _buildMobileTable(Set<String> selectedIds) {
    return ModernDataTable<Product>(
      columns: _buildColumns(true),
      items: widget.products,
      idGetter: (product) => product.id,
      selectedIds: selectedIds,
      shrinkWrap: true, // Fit table to content, no vertical scrolling
      horizontalScrollController: _scrollController,
      onSelectionChanged: (id, selected) {
        if (selected) {
          ref.read(productSelectionProvider.notifier).select(id);
        } else {
          ref.read(productSelectionProvider.notifier).deselect(id);
        }
      },
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
        context.push('${AppRoutes.products}/${product.id}');
      },
      rowHeight: 56.0, // Slightly smaller rows on mobile
      headerHeight: 44.0,
    );
  }

  List<ModernTableColumn<Product>> _buildColumns(bool isMobile) {
    return [
      // Image column
      ModernTableColumn<Product>(
        id: 'image',
        header: const SizedBox.shrink(),
        width: isMobile ? 48 : 64,
        alignment: Alignment.center,
        cellBuilder: (product) => _buildProductImage(product, isMobile),
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
        minWidth: isMobile ? 120 : 150,
        cellBuilder: (product) => Text(
          product.name,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // SKU column - hide on mobile
      if (!isMobile)
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
              fontFamily: AppTextStyles.fontFamilyMono,
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
        width: isMobile ? 100 : 130,
        alignment: Alignment.centerRight,
        cellBuilder: (product) => Text(
          CurrencyFormatter.format(product.sellingPrice),
          style: AppTextStyles.priceSmall.copyWith(
            color: AppColors.primary,
            fontSize: isMobile ? 12 : 14,
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
        width: isMobile ? 60 : 80,
        alignment: Alignment.center,
        cellBuilder: (product) => Text(
          '${product.stock}',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: _getStockColor(product),
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
        width: isMobile ? 80 : 100,
        alignment: Alignment.center,
        cellBuilder: (product) => _buildStatusBadge(product, isMobile),
      ),
      // Actions column
      ModernTableColumn<Product>(
        id: 'actions',
        header: const SizedBox.shrink(),
        width: isMobile ? 40 : 56,
        alignment: Alignment.center,
        cellBuilder: (product) => _buildActionButtons(context, product),
      ),
    ];
  }

  Widget _buildProductImage(Product product, bool isMobile) {
    final size = isMobile ? 36.0 : 48.0;
    return ProductImage(
      imagePath: product.imageUrl,
      size: size,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      placeholderIconSize: isMobile ? 18 : 24,
    );
  }

  Color _getStockColor(Product product) {
    if (product.isOutOfStock) {
      return AppColors.error;
    }
    if (product.isLowStock) {
      return AppColors.warning;
    }
    return AppColors.textPrimary;
  }

  Widget _buildStatusBadge(Product product, bool isMobile) {
    if (!product.isActive) {
      return ModernBadge.neutral(label: isMobile ? 'Off' : 'Nonaktif');
    }
    if (product.isOutOfStock) {
      return ModernBadge.error(label: isMobile ? 'Habis' : 'Habis');
    }
    if (product.isLowStock) {
      return ModernBadge.warning(label: isMobile ? 'Low' : 'Rendah');
    }
    return ModernBadge.success(label: isMobile ? 'Ok' : 'Aktif');
  }

  Widget _buildActionButtons(BuildContext context, Product product) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: const Icon(Icons.edit_outlined),
        iconSize: 20,
        color: AppColors.textSecondary,
        onPressed: () {
          context.push('${AppRoutes.products}/${product.id}/edit');
        },
        tooltip: 'Edit',
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
