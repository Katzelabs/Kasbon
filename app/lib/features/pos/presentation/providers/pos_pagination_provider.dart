import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/product_filter.dart';
import '../../../products/domain/usecases/get_paginated_products.dart';
import 'pos_search_provider.dart';

/// Page size for POS product pagination
const int kPosProductsPageSize = 10;

/// State class for POS paginated products
class PosPaginatedState extends Equatable {
  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const PosPaginatedState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  PosPaginatedState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
    bool clearError = false,
  }) {
    return PosPaginatedState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [products, isLoading, isLoadingMore, hasMore, currentPage, error];
}

/// StateNotifier for POS product pagination with infinite scroll
class PosPaginationNotifier extends StateNotifier<PosPaginatedState> {
  final GetPaginatedProducts _getPaginatedProducts;
  final Ref _ref;

  String? _currentSearchQuery;
  String? _currentCategoryId;

  PosPaginationNotifier(this._getPaginatedProducts, this._ref)
      : super(const PosPaginatedState()) {
    // Listen to search query changes
    _ref.listen(posSearchQueryProvider, (previous, next) {
      if (_currentSearchQuery != next) {
        _currentSearchQuery = next;
        reset();
      }
    });

    // Listen to category filter changes
    _ref.listen(posCategoryFilterProvider, (previous, next) {
      if (_currentCategoryId != next) {
        _currentCategoryId = next;
        reset();
      }
    });

    // Initialize current values
    _currentSearchQuery = _ref.read(posSearchQueryProvider);
    _currentCategoryId = _ref.read(posCategoryFilterProvider);

    // Load initial data
    loadInitial();
  }

  /// Load initial products (first page)
  Future<void> loadInitial() async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      products: [],
      currentPage: 0,
      hasMore: true,
    );

    await _loadProducts(page: 1, isInitial: true);
  }

  /// Load more products (next page)
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    await _loadProducts(page: state.currentPage + 1, isInitial: false);
  }

  /// Reset and reload (called when filters change)
  Future<void> reset() async {
    state = const PosPaginatedState();
    await loadInitial();
  }

  /// Internal method to load products
  Future<void> _loadProducts({required int page, required bool isInitial}) async {
    // Add debounce delay for search
    if (_currentSearchQuery?.isNotEmpty == true) {
      await Future.delayed(const Duration(milliseconds: 300));

      // Check if query changed during debounce
      if (_ref.read(posSearchQueryProvider) != _currentSearchQuery) {
        // Query changed, abort this request
        if (isInitial) {
          state = state.copyWith(isLoading: false);
        } else {
          state = state.copyWith(isLoadingMore: false);
        }
        return;
      }
    }

    final filter = ProductFilter(
      searchQuery:
          _currentSearchQuery?.isEmpty == true ? null : _currentSearchQuery,
      categoryId: _currentCategoryId,
      page: page,
      pageSize: kPosProductsPageSize,
    );

    final result = await _getPaginatedProducts(filter);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: failure.message,
        );
      },
      (paginatedResult) {
        final newProducts = isInitial
            ? paginatedResult.items
            : [...state.products, ...paginatedResult.items];

        state = state.copyWith(
          products: newProducts,
          isLoading: false,
          isLoadingMore: false,
          hasMore: paginatedResult.hasNextPage,
          currentPage: page,
          clearError: true,
        );
      },
    );
  }
}

/// Provider for POS paginated products
final posPaginationProvider =
    StateNotifierProvider.autoDispose<PosPaginationNotifier, PosPaginatedState>(
        (ref) {
  final getPaginatedProducts = getIt<GetPaginatedProducts>();
  return PosPaginationNotifier(getPaginatedProducts, ref);
});
