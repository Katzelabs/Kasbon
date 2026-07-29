import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/entities/product_filter.dart';
import '../providers/product_selection_provider.dart';
import '../providers/products_provider.dart';

/// Filter card widget for product list
/// Contains search field, category filter chips, stock filter chips, and sort dropdown
///
/// Two layouts. The full card is the stacked form the list has always had. The
/// compact bar - search plus a Filter button opening an adaptive sheet - is for
/// a master pane, where the full card would eat ~230dp of a ~400dp column.
///
/// Either layout also carries "Tambah Produk" when [onAddProduct] is given,
/// which is how everything wider than a phone reaches the add form. See
/// `ProductListPane` for why that action leaves the FAB behind.
class ProductFilterCard extends ConsumerStatefulWidget {
  const ProductFilterCard({super.key, this.onAddProduct});

  /// Opens the add-product form, or null when a FAB is doing that job instead.
  final VoidCallback? onAddProduct;

  @override
  ConsumerState<ProductFilterCard> createState() => _ProductFilterCardState();
}

class _ProductFilterCardState extends ConsumerState<ProductFilterCard> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only once the detail panel has squeezed the list below 600dp, where the
    // stacked card is ~230dp of what is left. `isCompact` alone would catch a
    // phone, whose list works today; `isInPane` alone no longer means narrow,
    // since the list is the side that keeps the room.
    if (context.isInPane && context.isCompact) return _buildCompactBar(context);

    final viewMode = ref.watch(productViewModeProvider);

    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field - full width on mobile
          _buildSearchField(),
          const SizedBox(height: AppDimensions.spacing12),
          // View Toggle, Sort Dropdown and - off a phone - the add button
          Row(
            children: [
              // View Toggle
              _buildViewToggle(viewMode),
              const SizedBox(width: AppDimensions.spacing12),
              // Sort Dropdown - flexible width
              // Measures the card's own width, not the window.
              Expanded(child: _SortDropdown(shortLabels: context.isCompact)),
              if (widget.onAddProduct != null) ...[
                const SizedBox(width: AppDimensions.spacing12),
                _buildAddButton(context),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          const _FilterChipSections(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return ModernSearchField(
      controller: _searchController,
      hint: 'Cari produk...',
      onChanged: (value) {
        ref.read(productFilterProvider.notifier).setSearchQuery(value);
      },
      onClear: () {
        ref.read(productFilterProvider.notifier).setSearchQuery(null);
      },
    );
  }

  /// Search plus a Filter button, for a list squeezed narrow by the detail
  /// panel beside it.
  ///
  /// No view toggle: at this width the list forces the grid, and offering a
  /// control that changes nothing is worse than not offering it.
  Widget _buildCompactBar(BuildContext context) {
    final filter = ref.watch(productFilterProvider);
    final activeCount = _activeFilterCount(filter);

    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: AppDimensions.spacing8),
        Badge(
          isLabelVisible: activeCount > 0,
          label: Text('$activeCount'),
          child: ModernIconButton.tonal(
            icon: Icons.tune,
            tooltip: 'Filter',
            onPressed: () => _openFilterSheet(context),
          ),
        ),
        // Icon only: this bar exists because the column is ~400dp wide, and a
        // labelled button here would cost the search field a third of it.
        if (widget.onAddProduct != null) ...[
          const SizedBox(width: AppDimensions.spacing8),
          ModernIconButton.filled(
            icon: Icons.add,
            tooltip: 'Tambah Produk',
            onPressed: widget.onAddProduct,
          ),
        ],
      ],
    );
  }

  /// The add button for the full card.
  ///
  /// Labelled where there is room for the words. At `medium` - a tablet in
  /// portrait, sharing the row with a view toggle and a sort dropdown - it
  /// drops to "Tambah", which is the same instruction in half the width.
  Widget _buildAddButton(BuildContext context) {
    return ModernButton.primary(
      onPressed: widget.onAddProduct,
      leadingIcon: Icons.add,
      child: Text(
        context.isAtLeast(Breakpoint.expanded) ? 'Tambah Produk' : 'Tambah',
      ),
    );
  }

  /// How many filters are narrowing the list, for the button's badge.
  ///
  /// The search box is excluded: it sits next to the button, so counting it
  /// would report a filter the user can already see.
  int _activeFilterCount(ProductFilter filter) {
    const defaults = ProductFilter();
    var count = 0;
    if (filter.categoryId != null) count++;
    if (filter.stockFilter != StockFilter.all) count++;
    if (filter.sortOption != defaults.sortOption) count++;
    return count;
  }

  Future<void> _openFilterSheet(BuildContext context) {
    // A bottom sheet below `expanded` and a right-edge side sheet above, which
    // is where this always ends up: a pane this narrow only exists inside a
    // window wide enough to have split in the first place.
    return ModernBottomSheet.showAdaptive<void>(
      context,
      title: 'Filter Produk',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortDropdown(shortLabels: false),
          SizedBox(height: AppDimensions.spacing16),
          _FilterChipSections(),
        ],
      ),
    );
  }

  Widget _buildViewToggle(ProductViewMode currentMode) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            icon: Icons.grid_view,
            isSelected: currentMode == ProductViewMode.grid,
            onTap: () {
              ref.read(productViewModeProvider.notifier).state =
                  ProductViewMode.grid;
              // Clear selection when switching to grid
              ref.read(productSelectionProvider.notifier).clearSelection();
            },
            tooltip: 'Tampilan Grid',
          ),
          _buildToggleButton(
            icon: Icons.table_rows,
            isSelected: currentMode == ProductViewMode.table,
            onTap: () {
              ref.read(productViewModeProvider.notifier).state =
                  ProductViewMode.table;
            },
            tooltip: 'Tampilan Tabel',
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sort order picker.
///
/// Its own widget rather than a method on the card, because it is also built
/// inside the filter sheet - which the root navigator builds, outside the
/// card's element, where the card's `ref` cannot subscribe anything.
class _SortDropdown extends ConsumerWidget {
  const _SortDropdown({required this.shortLabels});

  /// Whether to use each option's abbreviated label, for a narrow row.
  final bool shortLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(productFilterProvider).sortOption;

    return ModernDropdown<ProductSortOption>(
      value: selected,
      variant: ModernInputVariant.filled,
      hint: 'Urutkan',
      items: ProductSortOption.values.map((option) {
        return DropdownMenuItem<ProductSortOption>(
          value: option,
          child: Text(
            shortLabels ? option.shortLabel : option.label,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          ref.read(productFilterProvider.notifier).setSortOption(value);
        }
      },
    );
  }
}

/// The category and stock chip rows, shared by the card and the filter sheet.
class _FilterChipSections extends ConsumerWidget {
  const _FilterChipSections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final filter = ref.watch(productFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Kategori',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        SizedBox(
          height: 36,
          child: categoriesAsync.when(
            data: (categories) =>
                _buildCategoryChips(ref, categories, filter.categoryId),
            loading: () => const Center(child: ModernLoading.small()),
            error: (_, __) => _buildCategoryChips(ref, [], filter.categoryId),
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Text(
          'Stok',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        SizedBox(
          height: 36,
          child: _buildStockFilterChips(ref, filter.stockFilter),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(
    WidgetRef ref,
    List<Category> categories,
    String? selectedCategoryId,
  ) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        // "Semua" chip
        _chip(
          label: 'Semua',
          isSelected: selectedCategoryId == null,
          selectedColor: AppColors.primary,
          onSelected: (selected) {
            if (selected) {
              ref.read(productFilterProvider.notifier).setCategoryId(null);
            }
          },
        ),
        // Category chips from database
        ...categories.map((category) {
          final isSelected = selectedCategoryId == category.id;
          return _chip(
            label: category.name,
            isSelected: isSelected,
            selectedColor: AppColors.primary,
            onSelected: (selected) {
              ref
                  .read(productFilterProvider.notifier)
                  .setCategoryId(selected ? category.id : null);
            },
          );
        }),
      ],
    );
  }

  Widget _buildStockFilterChips(WidgetRef ref, StockFilter selectedFilter) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: StockFilter.values.map((filter) {
        return _chip(
          label: filter.label,
          isSelected: selectedFilter == filter,
          selectedColor: _stockFilterColor(filter),
          onSelected: (selected) {
            if (selected) {
              ref.read(productFilterProvider.notifier).setStockFilter(filter);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppDimensions.spacing8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: selectedColor,
        labelStyle: AppTextStyles.labelSmall.copyWith(
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
        backgroundColor: AppColors.surfaceVariant,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.spacing8),
      ),
    );
  }

  Color _stockFilterColor(StockFilter filter) {
    switch (filter) {
      case StockFilter.all:
        return AppColors.primary;
      case StockFilter.available:
        return AppColors.success;
      case StockFilter.lowStock:
        return AppColors.warning;
      case StockFilter.outOfStock:
        return AppColors.error;
    }
  }
}
