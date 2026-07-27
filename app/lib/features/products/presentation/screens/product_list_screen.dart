import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/product_selection_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_bulk_actions_bar.dart';
import '../widgets/product_filter_card.dart';
import '../widgets/product_grid_item.dart';
import '../widgets/product_table_view.dart';

/// Screen displaying list of all products with search and filter functionality
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  /// Whether the soft keyboard is covering part of the screen.
  ///
  /// Derived from the same `viewInsets` the layout below already does
  /// arithmetic on, rather than a parallel stream. The previous
  /// `KeyboardVisibilityController` subscription duplicated this and was never
  /// cancelled.
  bool get _isKeyboardVisible => MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(productViewModeProvider);
    final hasSelection = ref.watch(productSelectionProvider).isNotEmpty;

    // On mobile, FAB needs to be above bottom nav; on tablet, standard position
    final fabBottomOffset = context.isMobile
        ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
        : AppDimensions.spacing16;

    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Daftar Produk',
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(paginatedProductsProvider);
            },
            child: _buildContent(context, ref, viewMode, hasSelection),
          ),
          // FAB positioned based on device type - hidden when keyboard is visible
          if (!_isKeyboardVisible)
            Positioned(
              right: AppDimensions.spacing16,
              bottom: fabBottomOffset,
              child: FloatingActionButton(
                onPressed: () => context.go(AppRoutes.productAdd),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, ProductViewMode viewMode, bool hasSelection) {
    if (viewMode == ProductViewMode.table) {
      return _buildTableContent(context, ref, hasSelection);
    }
    return _buildGridContent(context, ref, hasSelection);
  }

  Widget _buildGridContent(BuildContext context, WidgetRef ref, bool hasSelection) {
    final padding = context.horizontalPadding;

    // Get keyboard height to avoid content being covered
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return CustomScrollView(
      slivers: [
        // Filter Card
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: const ProductFilterCard(),
          ),
        ),
        // Bulk Actions Bar (shown when items are selected)
        if (hasSelection)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: const ProductBulkActionsBar(),
            ),
          ),
        // Product Grid with bottom padding for FAB clearance
        _buildProductGrid(context, ref, hasSelection, keyboardHeight),
      ],
    );
  }

  Widget _buildTableContent(BuildContext context, WidgetRef ref, bool hasSelection) {
    final paginatedAsync = ref.watch(paginatedProductsProvider);
    final paginationInfo = ref.watch(paginationInfoProvider);
    final filter = ref.watch(productFilterProvider);
    final padding = context.horizontalPadding;

    // Get keyboard height to avoid content being covered
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Calculate bottom padding: bottom nav on mobile + spacing + keyboard
    final bottomPadding = context.isMobile
        ? AppDimensions.bottomNavHeight + AppDimensions.spacing16 + keyboardHeight
        : AppDimensions.spacing16 + keyboardHeight;

    return CustomScrollView(
      slivers: [
        // Filter Card
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: const ProductFilterCard(),
          ),
        ),
        // Bulk Actions Bar (shown when items are selected)
        if (hasSelection)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: const ProductBulkActionsBar(),
            ),
          ),
        // Table View
        paginatedAsync.when(
          data: (result) {
            if (result.isEmpty) {
              if (filter.hasActiveFilters) {
                return SliverFillRemaining(
                  child: ModernEmptyState.search(
                    message: 'Tidak ada produk yang cocok dengan filter',
                  ),
                );
              }
              return SliverFillRemaining(
                child: ModernEmptyState.list(
                  title: 'Belum Ada Produk',
                  message: 'Tambahkan produk pertama Anda',
                  actionLabel: 'Tambah Produk',
                  onAction: () => context.go(AppRoutes.productAdd),
                ),
              );
            }

            final products = result.items;

            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Table fits exactly to content - no scrolling needed
                    ProductTableView(products: products),
                    // Gap before pagination
                    if (paginationInfo != null && paginationInfo.totalPages > 1)
                      const SizedBox(height: AppDimensions.spacing16),
                    // Pagination Controls
                    if (paginationInfo != null && paginationInfo.totalPages > 1)
                      ModernPaginationControls(
                        currentPage: paginationInfo.currentPage,
                        totalPages: paginationInfo.totalPages,
                        displayText: paginationInfo.displayText,
                        onPageChanged: (page) => ref
                            .read(productFilterProvider.notifier)
                            .goToPage(page),
                        onPreviousPage: paginationInfo.hasPrevious
                            ? () => ref
                                .read(productFilterProvider.notifier)
                                .previousPage()
                            : null,
                        onNextPage: paginationInfo.hasNext
                            ? () => ref
                                .read(productFilterProvider.notifier)
                                .nextPage()
                            : null,
                      ),
                    SizedBox(height: bottomPadding),
                  ],
                ),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: ModernLoading()),
          ),
          error: (error, _) => SliverFillRemaining(
            child: ModernErrorState.generic(
              message: 'Gagal memuat produk. ${error.toString()}',
              onRetry: () => ref.invalidate(paginatedProductsProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(
      BuildContext context, WidgetRef ref, bool hasSelection, double keyboardHeight) {
    final paginatedAsync = ref.watch(paginatedProductsProvider);
    final paginationInfo = ref.watch(paginationInfoProvider);
    final filter = ref.watch(productFilterProvider);
    final selectedIds = ref.watch(productSelectionProvider);

    return paginatedAsync.when(
      data: (result) {
        if (result.isEmpty) {
          // Check if it's a search/filter result or truly empty
          if (filter.hasActiveFilters) {
            return SliverFillRemaining(
              child: ModernEmptyState.search(
                message: 'Tidak ada produk yang cocok dengan filter',
              ),
            );
          }

          return SliverFillRemaining(
            child: ModernEmptyState.list(
              title: 'Belum Ada Produk',
              message: 'Tambahkan produk pertama Anda',
              actionLabel: 'Tambah Produk',
              onAction: () => context.go(AppRoutes.productAdd),
            ),
          );
        }

        final products = result.items;

        // Calculate responsive grid columns
        final columns = _getGridColumns(context);
        final padding = context.horizontalPadding;

        // Calculate bottom padding for bottom nav on mobile + spacing + keyboard
        final bottomPadding = context.isMobile
            ? AppDimensions.bottomNavHeight + AppDimensions.spacing16 + keyboardHeight
            : AppDimensions.spacing16 + keyboardHeight;

        // Aspect ratio for grid items (lower = taller cards)
        const aspectRatio = 0.65;

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 0, padding, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppDimensions.spacing12,
                  crossAxisSpacing: AppDimensions.spacing12,
                  childAspectRatio: aspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];
                    final isSelected = selectedIds.contains(product.id);

                    return ProductGridItem(
                      product: product,
                      isSelectionMode: hasSelection,
                      isSelected: isSelected,
                      onTap: hasSelection
                          ? () => _toggleSelection(ref, product.id, isSelected)
                          : () => context.go(AppRoutes.productDetailPath(product.id)),
                      onLongPress: () => _enterSelectionMode(ref, product.id),
                    );
                  },
                  childCount: products.length,
                ),
              ),
            ),
            // Gap before pagination
            if (paginationInfo != null && paginationInfo.totalPages > 1)
              const SliverToBoxAdapter(
                child: SizedBox(height: AppDimensions.spacing16),
              ),
            // Pagination Controls - with horizontal padding matching grid
            if (paginationInfo != null && paginationInfo.totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: ModernPaginationControls(
                    currentPage: paginationInfo.currentPage,
                    totalPages: paginationInfo.totalPages,
                    displayText: paginationInfo.displayText,
                    onPageChanged: (page) =>
                        ref.read(productFilterProvider.notifier).goToPage(page),
                    onPreviousPage: paginationInfo.hasPrevious
                        ? () =>
                            ref.read(productFilterProvider.notifier).previousPage()
                        : null,
                    onNextPage: paginationInfo.hasNext
                        ? () => ref.read(productFilterProvider.notifier).nextPage()
                        : null,
                  ),
                ),
              ),
            // Bottom padding for FAB
            SliverToBoxAdapter(
              child: SizedBox(height: bottomPadding),
            ),
          ],
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: ModernLoading()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: ModernErrorState.generic(
          message: 'Gagal memuat produk. ${error.toString()}',
          onRetry: () => ref.invalidate(paginatedProductsProvider),
        ),
      ),
    );
  }

  /// Toggle selection for a product
  void _toggleSelection(WidgetRef ref, String productId, bool isCurrentlySelected) {
    if (isCurrentlySelected) {
      ref.read(productSelectionProvider.notifier).deselect(productId);
    } else {
      ref.read(productSelectionProvider.notifier).select(productId);
    }
  }

  /// Enter selection mode by selecting a product
  void _enterSelectionMode(WidgetRef ref, String productId) {
    ref.read(productSelectionProvider.notifier).select(productId);
  }

  /// Get responsive grid columns based on screen width
  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return 2; // Small mobile
    } else if (width < 900) {
      return 2; // Large mobile
    } else {
      return 5; // Tablet and above - 5 columns
    }
  }
}
