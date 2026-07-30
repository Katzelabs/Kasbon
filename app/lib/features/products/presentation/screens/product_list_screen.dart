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
import '../widgets/product_add_action.dart';
import '../widgets/product_bulk_actions_bar.dart';
import '../widgets/product_detail_panel.dart';
import '../widgets/product_filter_card.dart';
import '../widgets/product_grid_item.dart';
import '../widgets/product_table_view.dart';

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
        // Hides itself on a phone, where the FAB in the list pane below does
        // this job instead.
        additionalActions: const [ProductAddAction()],
      ),
      body: MasterDetailScaffold(
        basePath: AppRoutes.products,
        selectionParser: AppRoutes.selectedProductId,
        // The panel gets purpose-built chrome, not the full detail screen: a
        // Scaffold docked inside another screen's body meant a second app bar
        // and actions that scrolled out of reach.
        //
        // Only the detail, never the form. Editing is a full-screen route at
        // every width - see the note on the edit route in `app_router.dart` -
        // so `/products/:id/edit` shows this panel with the form on top of it,
        // and the panel is what you come back to when the form closes.
        detailBuilder: (context, uri, id) => ProductDetailPanel(
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
        if (_usesFab(context) && !_isKeyboardVisible)
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

  /// Where "Tambah Produk" lives: floating over the grid, or in the header.
  ///
  /// A FAB is a phone affordance. Given a pointer and a toolbar it is the wrong
  /// shape twice over - it hovers over the last row of products, and it puts
  /// the screen's primary action in the one corner a mouse is never already
  /// near. So anything wider than a phone gets a real button in the header
  /// (`ProductAddAction`) and only a compact window keeps the FAB.
  ///
  /// [isInPane] is part of the test because a master pane squeezed below 600dp
  /// is *not* a phone: the window around it is a desktop, and the header
  /// spanning it - which is not this pane, and does not narrow with it - is
  /// still carrying the add button.
  ///
  /// The two conditions are complements by construction: `ProductAddAction`
  /// hides at `compact` measured against the content area, and a pane can only
  /// be `compact` while not in a pane when the content area is too.
  static bool _usesFab(BuildContext context) =>
      context.isCompact && !context.isInPane;

  Widget _buildContent(BuildContext context, WidgetRef ref,
      ProductViewMode viewMode, bool hasSelection) {
    if (viewMode == ProductViewMode.table) {
      return _buildTableContent(context, ref, hasSelection);
    }
    return _buildGridContent(context, ref, hasSelection);
  }

  Widget _buildGridContent(
      BuildContext context, WidgetRef ref, bool hasSelection) {
    final padding = context.contentPadding;

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

  Widget _buildTableContent(
      BuildContext context, WidgetRef ref, bool hasSelection) {
    final paginatedAsync = ref.watch(paginatedProductsProvider);
    final paginationInfo = ref.watch(paginationInfoProvider);
    final filter = ref.watch(productFilterProvider);
    final padding = context.contentPadding;

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

  Widget _buildProductGrid(BuildContext context, WidgetRef ref,
      bool hasSelection, double keyboardHeight) {
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

        final padding = context.contentPadding;

        // Calculate bottom padding for shell nav + spacing + keyboard
        final bottomPadding =
            AppDimensions.spacing16 + context.shellBottomInset + keyboardHeight;

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 0, padding, 0),
              // The grid is sized from the room it is actually given, which is
              // this sliver's cross-axis extent - the pane's width less the
              // padding above. Reading a breakpoint instead would only tell it
              // which tier it is in, and a tier is not a width: `large` covers
              // everything from a 1200dp laptop to a 2560dp monitor.
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = _gridColumns(constraints.crossAxisExtent);
                  final tileWidth = (constraints.crossAxisExtent -
                          _gridSpacing * (columns - 1)) /
                      columns;

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: _gridSpacing,
                      crossAxisSpacing: _gridSpacing,
                      // Not an aspect ratio: the card states the height its
                      // photo and its type need, and the grid grants it.
                      mainAxisExtent:
                          ProductGridItem.extentFor(context, tileWidth),
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
                              ? () =>
                                  _toggleSelection(ref, product.id, isSelected)
                              : () => context
                                  .go(AppRoutes.productDetailPath(product.id)),
                          onLongPress: () =>
                              _enterSelectionMode(ref, product.id),
                        );
                      },
                      childCount: products.length,
                    ),
                  );
                },
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
                        ? () => ref
                            .read(productFilterProvider.notifier)
                            .previousPage()
                        : null,
                    onNextPage: paginationInfo.hasNext
                        ? () =>
                            ref.read(productFilterProvider.notifier).nextPage()
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
  void _toggleSelection(
      WidgetRef ref, String productId, bool isCurrentlySelected) {
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

  /// Gap between cards, both ways.
  static const double _gridSpacing = AppDimensions.spacing12;

  /// The card width the grid aims for, before it is rounded to whole columns.
  ///
  /// Chosen so a product photo is large enough to recognise at a glance and the
  /// name below it gets two readable lines. The count follows from the width
  /// rather than the other way round, so the cards stay about this size at
  /// every window: 2 across on a phone, 4 on a tablet, 6-7 on a laptop, a dozen
  /// on a 2560px monitor.
  static const double _targetCardWidth = 200;

  /// How many columns fit in [width], rounded to the nearest whole card.
  ///
  /// Rounding rather than flooring: at 600dp `floor` would give 2 columns of
  /// 294dp - cards half again as wide as they want to be - where `round` gives
  /// 3 of 192dp, which is what was asked for.
  ///
  /// Never fewer than two. A single column of cards is a list, and the list has
  /// a table view for that.
  static int _gridColumns(double width) {
    final columns = (width / _targetCardWidth).round();
    return columns < 2 ? 2 : columns;
  }
}
