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
import '../widgets/product_detail_panel.dart';
import '../widgets/product_filter_card.dart';
import '../widgets/product_grid_item.dart';
import '../widgets/product_table_view.dart';
import 'product_form_screen.dart';

/// Screen displaying list of all products with search and filter functionality.
///
/// ## One screen, one header, the split inside it
///
/// The screen owns the `Scaffold` and the app bar, and the body divides into
/// the list and a docked detail panel - the arrangement `PosScreen` uses for
/// its cart. Wrapping the *whole screen* in the split instead would put the
/// header inside the left pane, so "Daftar Produk" would stop short of the
/// panel and the panel would start at the very top of the content area, level
/// with the header rather than under it.
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Daftar Produk',
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: MasterDetailScaffold(
        basePath: AppRoutes.products,
        selectionParser: AppRoutes.selectedProductId,
        // The panel gets purpose-built chrome, not the full detail screen: a
        // Scaffold docked inside another screen's body meant a second app bar
        // and actions that scrolled out of reach.
        detailBuilder: (context, uri, id) =>
            uri.pathSegments.length > 2 && uri.pathSegments[2] == 'edit'
                // Keyed by id for the same reason the edit route is: switching
                // selection with the form open must load the new record rather
                // than keep editing the old one.
                ? ProductFormScreen(key: ValueKey('form-$id'), productId: id)
                : ProductDetailPanel(
                    key: ValueKey('detail-$id'),
                    productId: id,
                    onClose: () => MasterDetailScaffold.closeDetail(
                      context,
                      AppRoutes.products,
                    ),
                  ),
        placeholderBuilder: (context) => const _DetailPanePlaceholder(),
        master: const ProductListPane(),
      ),
    );
  }
}

/// What the detail panel shows before anything is selected.
class _DetailPanePlaceholder extends StatelessWidget {
  const _DetailPanePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ModernEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Pilih Produk',
      message: 'Pilih produk dari daftar untuk melihat detailnya',
    );
  }
}

/// The product list itself, filling whichever pane it is given.
///
/// Split out from [ProductListScreen] so that everything it reads - the view
/// mode, the grid's column count, the filter card's layout - is measured
/// against the *pane*, not against the content area the header spans.
class ProductListPane extends ConsumerStatefulWidget {
  const ProductListPane({super.key});

  @override
  ConsumerState<ProductListPane> createState() => _ProductListPaneState();
}

class _ProductListPaneState extends ConsumerState<ProductListPane> {
  /// Whether the soft keyboard is covering part of the screen.
  ///
  /// Derived from the same `viewInsets` the layout below already does
  /// arithmetic on, rather than a parallel stream. The previous
  /// `KeyboardVisibilityController` subscription duplicated this and was never
  /// cancelled.
  bool get _isKeyboardVisible => MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  Widget build(BuildContext context) {
    // A table needs columns this list does not have once the detail panel has
    // squeezed it below 600dp - name, price and stock cannot share a row that
    // narrow. The toggle that sets this is hidden there too, so the mode is
    // not merely overridden behind the user's back.
    //
    // Both halves of the test matter. `isCompact` alone would catch a phone,
    // which shows the table happily today; `isInPane` alone no longer means
    // narrow, because the list is the side that keeps the room.
    final viewMode = context.isInPane && context.isCompact
        ? ProductViewMode.grid
        : ref.watch(productViewModeProvider);
    final hasSelection = ref.watch(productSelectionProvider).isNotEmpty;

    // On mobile, FAB needs to be above bottom nav; on tablet, standard position
    final fabBottomOffset = AppDimensions.spacing16 + context.shellBottomInset;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paginatedProductsProvider);
          },
          child: _buildContent(context, ref, viewMode, hasSelection),
        ),
        // Inside the list pane, so it stays over the products rather than
        // floating above the detail panel.
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

    // Calculate bottom padding: shell nav + spacing + keyboard
    final bottomPadding =
        AppDimensions.spacing16 + context.shellBottomInset + keyboardHeight;

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

        // Calculate bottom padding for shell nav + spacing + keyboard
        final bottomPadding = AppDimensions.spacing16 +
            context.shellBottomInset +
            keyboardHeight;

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

  /// Get responsive grid columns for the space the grid actually has.
  ///
  /// Reads the breakpoint scope rather than the window: this list becomes a
  /// master pane in RESP_07, where asking the window would give a 400dp column
  /// five products across.
  ///
  /// The tier values reproduce the thresholds this replaced - the old code
  /// returned 2 below 600, 2 below 900, and 5 above.
  int _getGridColumns(BuildContext context) => context.responsive<int>(
        compact: 2,
        medium: 2,
        expanded: 5,
      );
}
