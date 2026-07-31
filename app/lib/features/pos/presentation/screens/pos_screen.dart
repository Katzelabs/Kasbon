import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/cart_operation_result.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_layout_provider.dart';
import '../providers/pos_pagination_provider.dart';
import '../providers/pos_search_provider.dart';
import '../widgets/cart_panel.dart';
import '../widgets/cart_summary_bar.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/pos_cart_action.dart';
import '../widgets/pos_shortcuts.dart';
import '../widgets/product_grid_item.dart';

/// Point of Sale (Kasir) screen
///
/// Two layouts, chosen by how wide the *pane* is rather than by what the device
/// is called - see [PosLayout.showsCartSidebar]:
///
/// - **Overlay** (below `expanded`): full-width product grid, a floating cart
///   summary bar, and the cart as a modal sheet.
/// - **Split** (`expanded` and above): product grid beside a docked
///   [CartPanel], collapsible from the header.
///
/// Off a phone the header carries the cart control ([PosCartAction]) - the
/// toggle in the split layout, the way into the modal sheet at `medium`.
///
/// The grid itself has no column count. It is scoped to the space it occupies
/// and sized by [PosLayout.productTileMaxExtent], so the rail expanding, the
/// cart collapsing and the window resizing are all the same event to it: the
/// pane got wider or narrower.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'pos-search');

  /// Whether the soft keyboard is covering part of the screen.
  ///
  /// Reading `viewInsets` is reactive - the dependency it registers rebuilds
  /// this widget when the keyboard opens or closes, which is what the previous
  /// `KeyboardVisibilityController.onChange.listen` did by hand, minus the
  /// subscription that was never cancelled.
  bool get _isKeyboardVisible => MediaQuery.viewInsetsOf(context).bottom > 0;

  /// Threshold for triggering load more (pixels from bottom)
  static const double _loadMoreThreshold = 200.0;

  @override
  void initState() {
    super.initState();

    // Add scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Check if user scrolled near the bottom
    if (maxScroll - currentScroll <= _loadMoreThreshold) {
      ref.read(posPaginationProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Move focus to the search field and select what is already in it, so the
  /// next keystroke replaces the last query rather than appending to it.
  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  /// The cashier fast path: type enough to narrow the grid to one product,
  /// press Enter, and it is in the cart.
  ///
  /// Deliberately requires *exactly* one visible result. With two, guessing
  /// which one was meant would put the wrong item on a receipt, and a cashier
  /// who has to check what got added is slower than one who taps.
  void _addSoleSearchResult() {
    final products = ref.read(posPaginationProvider).products;
    if (products.length != 1) return;

    _addToCart(products.single);
    _searchController.clear();
    ref.read(posSearchQueryProvider.notifier).state = '';
  }

  /// Open the payment dialog, if there is anything to pay for.
  Future<void> _checkout() async {
    if (ref.read(cartProvider).isEmpty) return;
    await PaymentDialog.show(context);
  }

  /// Show confirmation dialog before clearing cart.
  ///
  /// Delegates to [CartPanel] so the Ctrl+Backspace path and the cart's own
  /// "Hapus Semua" button ask the identical question.
  Future<void> _confirmClearCart() => CartPanel.confirmClearCart(context, ref);

  /// Back out of the current context: drop the search filter if there is one,
  /// otherwise just give up focus so the grid is scrollable by keyboard again.
  void _dismiss() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      ref.read(posSearchQueryProvider.notifier).state = '';
      return;
    }
    FocusScope.of(context).unfocus();
  }

  /// Add [product] to the cart and report what happened.
  ///
  /// Shared by the grid tap and the Enter-in-search fast path, so a keyboard
  /// sale and a tapped one cannot diverge on stock handling.
  void _addToCart(Product product) {
    final result = ref.read(cartProvider.notifier).addProduct(product);

    if (result.isSuccess) {
      ModernToast.success(
        context,
        '${product.name} ditambahkan ke keranjang',
        duration: const Duration(seconds: 1),
      );
    } else if (result.result == CartOperationResult.outOfStock) {
      ModernToast.error(context, '${product.name} habis');
    } else if (result.result == CartOperationResult.exceedsStock) {
      ModernToast.warning(
        context,
        'Stok tidak mencukupi. Tersisa ${result.availableStock} ${result.unit}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The pane, not the window. Inside the shell this is the space left after
    // the navigation rail, which is what decides whether a docked cart fits.
    final layout = context.breakpointData;

    return PosShortcuts(
      onFocusSearch: _focusSearch,
      onCheckout: _checkout,
      onClearCart: _confirmClearCart,
      onDismiss: _dismiss,
      child: Scaffold(
        // Prevent body resize when keyboard appears to keep cart summary bar positioned correctly
        resizeToAvoidBottomInset: false,
        appBar: ModernAppBar.withActions(
          title: 'Kasir',
          // Toggles the docked cart in the split layout and opens the modal one
          // at `medium`; hides itself on a phone, which keeps the summary bar.
          additionalActions: const [PosCartAction()],
        ),
        body: PosLayout.showsCartSidebar(layout.breakpoint)
            ? _buildSplitLayout(layout)
            : _buildOverlayLayout(),
      ),
    );
  }

  /// Grid across the full pane, cart reachable through the summary bar.
  Widget _buildOverlayLayout() {
    // Was a local `const bottomNavHeight = 80.0`, duplicating
    // AppDimensions.bottomNavHeight where the two could drift apart
    // independently.
    final shellBottomInset = context.shellBottomInset;

    return Stack(
      children: [
        Column(
          children: [
            _buildSearchAndFilterCard(),
            Expanded(
              child: _buildProductGrid(
                // Both the summary bar and the shell's bottom bar float over
                // the grid, so the last row needs room for whichever are
                // present.
                extraBottomPadding:
                    shellBottomInset + PosLayout.cartSummaryBarInset,
              ),
            ),
          ],
        ),
        // Floating cart summary bar - positioned above bottom nav, hidden when keyboard is visible
        if (!_isKeyboardVisible)
          Positioned(
            bottom: shellBottomInset,
            left: 0,
            right: 0,
            child: const CartSummaryBar(),
          ),
      ],
    );
  }

  /// Grid beside a docked cart.
  ///
  /// Neither side is given a column count or a fixed width by anything outside
  /// this method: the cart takes its share of [layout], the grid gets the rest
  /// and re-scopes to it, and the tile extent does the rest.
  ///
  /// A collapsed cart is reopened from the header ([PosCartAction]), not from a
  /// floating button over the products - see that widget for why the FAB went.
  Widget _buildSplitLayout(BreakpointData layout) {
    final isCartExpanded = ref.watch(posCartExpandedProvider);
    final cartWidth = PosLayout.cartSidebarWidth(layout);

    return Row(
      children: [
        Expanded(
          // The grid pane measures itself. Collapsing the cart widens this
          // by ~350dp and the grid gains columns from that alone, which is
          // what deleted the cart-and-rail-state column ladder.
          child: ModernBreakpointScope.fromLayout(
            child: Column(
              children: [
                _buildSearchAndFilterCard(),
                Expanded(child: _buildProductGrid()),
              ],
            ),
          ),
        ),
        _buildCartSidebar(
          isExpanded: isCartExpanded,
          width: cartWidth,
        ),
      ],
    );
  }

  Widget _buildCartSidebar({
    required bool isExpanded,
    required double width,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isExpanded ? width : 0,
      child: isExpanded
          ? ClipRect(
              // Mid-animation the container is narrower than the panel needs.
              // Laying the panel out at its final width and clipping the
              // overflow makes the cart slide in from the edge; without this
              // it reflows every frame and overflows while it does.
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: width,
                maxWidth: width,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: CartPanel.sidebar(
                    onClose: () => ref
                        .read(posCartExpandedProvider.notifier)
                        .state = false,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSearchAndFilterCard() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategoryId = ref.watch(posCategoryFilterProvider);

    return ModernCard.elevated(
      margin: const EdgeInsets.all(AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search field
          ModernSearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hint: 'Cari produk...',
            onChanged: (value) {
              ref.read(posSearchQueryProvider.notifier).state = value;
            },
            // Enter on a search that has narrowed to a single product adds it
            // straight to the cart - the scan-less equivalent of a barcode.
            onSubmitted: (_) => _addSoleSearchResult(),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          // Category chips - sized to the minimum touch target, since a
          // cashier taps these constantly and often one-handed.
          SizedBox(
            height: AppDimensions.minTouchTarget,
            child: categoriesAsync.when(
              loading: () => const Center(child: ModernLoading.small()),
              error: (_, __) => const SizedBox.shrink(),
              data: (categories) {
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppDimensions.spacing8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = selectedCategoryId == null;
                      return ChoiceChip(
                        label: const Text('Semua'),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(posCategoryFilterProvider.notifier).state =
                              null;
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusRound),
                        ),
                        side: BorderSide.none,
                      );
                    }

                    final category = categories[index - 1];
                    final isSelected = selectedCategoryId == category.id;
                    return ChoiceChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(posCategoryFilterProvider.notifier).state =
                            category.id;
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusRound),
                      ),
                      side: BorderSide.none,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid({double extraBottomPadding = 0}) {
    final paginatedState = ref.watch(posPaginationProvider);
    final cart = ref.watch(cartProvider);

    // Handle initial loading state
    if (paginatedState.isLoading && paginatedState.products.isEmpty) {
      return const Center(child: ModernLoading());
    }

    // Handle error state
    if (paginatedState.error != null && paginatedState.products.isEmpty) {
      return ModernErrorState(
        message: paginatedState.error!,
        onRetry: () => ref.read(posPaginationProvider.notifier).loadInitial(),
      );
    }

    // Handle empty state
    if (!paginatedState.isLoading && paginatedState.products.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Produk Tidak Ditemukan',
        message: 'Coba ubah kata kunci atau filter kategori',
      );
    }

    final products = paginatedState.products;
    // Add 1 extra item for loading indicator when loading more
    final itemCount = products.length + (paginatedState.isLoadingMore ? 1 : 0);

    // Traversal group so Tab walks the product grid to its end before leaving
    // for the cart. Without it, tab order follows the widget tree and a
    // keyboard user lands in the cart part-way down the grid.
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: AppDimensions.spacing16,
          right: AppDimensions.spacing16,
          top: AppDimensions.spacing16,
          bottom: AppDimensions.spacing16 + extraBottomPadding,
        ),
        // Max extent rather than a column count: the grid fits as many 220dp
        // tiles as the pane holds and stretches them to fill the remainder. A
        // phone gets 2, a desktop pane with the cart closed gets 7, and no
        // ladder of breakpoints has to be maintained to say so.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: PosLayout.productTileMaxExtent,
          crossAxisSpacing: AppDimensions.spacing12,
          mainAxisSpacing: AppDimensions.spacing12,
          childAspectRatio: 0.75,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Show loading indicator for the last item when loading more
          if (index >= products.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacing16),
                child: ModernLoading.small(),
              ),
            );
          }

          final product = products[index];
          // Find quantity in cart
          final cartItem = cart.where((c) => c.product.id == product.id);
          final quantityInCart =
              cartItem.isNotEmpty ? cartItem.first.quantity : 0;

          return ProductGridItem(
            product: product,
            quantityInCart: quantityInCart,
            onTap: () => _addToCart(product),
          );
        },
      ),
    );
  }
}
