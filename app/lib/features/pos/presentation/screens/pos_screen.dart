import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../../shared/providers/navigation_sidebar_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_operation_result.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_pagination_provider.dart';
import '../providers/pos_search_provider.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/cart_summary_bar.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_grid_item.dart';

/// Point of Sale (Kasir) screen
///
/// Mobile layout:
/// - Full-screen product grid
/// - Floating cart button with item count
/// - Bottom sheet for cart details
///
/// Tablet layout:
/// - Split panel: Product grid (left ~60%) + Cart sidebar (right ~40%)
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isCartExpanded = true;

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
    super.dispose();
  }

  /// Show confirmation dialog before clearing cart
  Future<void> _confirmClearCart() async {
    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Hapus Semua Item?',
      message: 'Semua item di keranjang akan dihapus.',
      confirmLabel: 'Hapus Semua',
      cancelLabel: 'Batal',
      isDestructive: true,
    );

    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Prevent body resize when keyboard appears to keep cart summary bar positioned correctly
      resizeToAvoidBottomInset: false,
      appBar: ModernAppBar.withActions(
        title: 'Kasir',
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: context.isMobile ? _buildMobileLayout() : _buildTabletLayout(),
    );
  }

  Widget _buildMobileLayout() {
    // Was a local `const bottomNavHeight = 80.0`, duplicating
    // AppDimensions.bottomNavHeight where the two could drift apart
    // independently.
    final shellBottomInset = context.shellBottomInset;

    return Stack(
      children: [
        // Main content
        Column(
          children: [
            // Search and category filter in card
            _buildSearchAndFilterCard(),
            // Product grid
            Expanded(
              child: _buildProductGrid(crossAxisCount: 2),
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

  Widget _buildTabletLayout() {
    // The rail's width is a function of the window tier as well as the stored
    // preference - at `medium` it is pinned collapsed regardless. Resolve both
    // rather than reading the raw preference, which is null until the user
    // touches the toggle.
    final isNavSidebarExpanded = resolveRailExpanded(
      context.windowBreakpoint,
      ref.watch(navigationSidebarExpandedProvider),
    );

    // Calculate grid columns based on sidebar visibility:
    // - Cart hidden → 5 columns (regardless of nav state)
    // - Cart visible + nav collapsed → 4 columns
    // - Cart visible + nav expanded → 3 columns
    int gridColumns;
    if (!_isCartExpanded) {
      gridColumns = 5;
    } else if (isNavSidebarExpanded) {
      gridColumns = 3;
    } else {
      gridColumns = 4;
    }

    return Stack(
      children: [
        Row(
          children: [
            // Product grid section (left)
            Expanded(
              child: Column(
                children: [
                  // Search and category filter in card
                  _buildSearchAndFilterCard(),
                  // Product grid - columns based on sidebar visibility
                  Expanded(
                    child: _buildProductGrid(
                      crossAxisCount: gridColumns,
                    ),
                  ),
                ],
              ),
            ),
            // Cart sidebar (right) - animated
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isCartExpanded ? 350 : 0,
              child: _isCartExpanded
                  ? Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildCartSidebar(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        // FAB when cart is collapsed - hidden when keyboard is visible
        if (!_isCartExpanded && !_isKeyboardVisible) _buildCartFab(),
      ],
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
            hint: 'Cari produk...',
            onChanged: (value) {
              ref.read(posSearchQueryProvider.notifier).state = value;
            },
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

  Widget _buildProductGrid({required int crossAxisCount}) {
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
    final itemCount =
        products.length + (paginatedState.isLoadingMore ? 1 : 0);

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: AppDimensions.spacing16,
        right: AppDimensions.spacing16,
        top: AppDimensions.spacing16,
        // Extra bottom padding for mobile to account for cart bar + bottom nav
        bottom: context.isMobile
            ? AppDimensions.spacing16 + 160 // cart bar (~64) + bottom nav (~80) + spacing
            : AppDimensions.spacing16,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
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
          onTap: () {
            final result =
                ref.read(cartProvider.notifier).addProduct(product);

            // Show appropriate feedback based on result
            if (result.isSuccess) {
              ModernToast.success(
                context,
                '${product.name} ditambahkan ke keranjang',
                duration: const Duration(seconds: 1),
              );
            } else if (result.result == CartOperationResult.outOfStock) {
              ModernToast.error(
                context,
                '${product.name} habis',
              );
            } else if (result.result == CartOperationResult.exceedsStock) {
              ModernToast.warning(
                context,
                'Stok tidak mencukupi. Tersisa ${result.availableStock} ${result.unit}',
              );
            }
          },
        );
      },
    );
  }

  Widget _buildCartFab() {
    final itemCount = ref.watch(cartItemCountProvider);

    return Positioned(
      right: AppDimensions.spacing16,
      bottom: AppDimensions.spacing16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton(
            onPressed: () => setState(() => _isCartExpanded = true),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.shopping_cart, color: Colors.white),
          ),
          if (itemCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  itemCount > 99 ? '99+' : '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartSidebar() {
    final cart = ref.watch(cartProvider);
    final itemCount = ref.watch(cartItemCountProvider);
    final total = ref.watch(cartTotalProvider);
    final hasStockWarning = ref.watch(cartHasStockWarningProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cart header
        Container(
          padding: const EdgeInsets.only(
            left: AppDimensions.spacing16,
            right: AppDimensions.spacing8,
            top: AppDimensions.spacing12,
            bottom: AppDimensions.spacing12,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              const Text(
                'Keranjang',
                style: AppTextStyles.h4,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                '($itemCount)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (cart.isNotEmpty)
                ModernButton.text(
                  onPressed: () => _confirmClearCart(),
                  size: ModernSize.small,
                  child: Text(
                    'Hapus Semua',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () => setState(() => _isCartExpanded = false),
                icon: const Icon(Icons.close),
                iconSize: AppDimensions.iconMedium,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppDimensions.minTouchTarget,
                  minHeight: AppDimensions.minTouchTarget,
                ),
                tooltip: 'Tutup keranjang',
              ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child: cart.isEmpty ? _buildEmptyCart() : _buildCartItems(cart),
        ),
        // Stock warning
        if (hasStockWarning)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
              vertical: AppDimensions.spacing8,
            ),
            color: AppColors.warningLight,
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: AppDimensions.iconMedium,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'Beberapa item melebihi stok yang tersedia',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Cart footer
        _buildCartFooter(total, cart.isNotEmpty),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            'Keranjang Kosong',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Pilih produk untuk menambahkan ke keranjang',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(List<CartItem> cart) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      itemCount: cart.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacing12),
      itemBuilder: (context, index) {
        final item = cart[index];
        return CartItemTile(
          item: item,
          onQuantityChanged: (qty) {
            final result = ref
                .read(cartProvider.notifier)
                .updateQuantity(item.product.id, qty);

            if (result.result == CartOperationResult.exceedsStock) {
              ModernToast.warning(
                context,
                'Stok maksimal ${result.availableStock} ${result.unit}',
              );
            }
          },
          onRemove: () {
            ref.read(cartProvider.notifier).removeProduct(item.product.id);
          },
        );
      },
    );
  }

  Widget _buildCartFooter(double total, bool hasItems) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: AppShadows.up,
      ),
      child: Column(
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                CurrencyFormatter.format(total),
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          // Checkout button
          ModernButton.primary(
            onPressed: hasItems
                ? () async {
                    final result = await PaymentDialog.show(context);
                    if (result == true) {
                      // Payment was successful - navigation handled by dialog
                    }
                  }
                : null,
            fullWidth: true,
            size: ModernSize.large,
            child: const Text('BAYAR'),
          ),
        ],
      ),
    );
  }
}
