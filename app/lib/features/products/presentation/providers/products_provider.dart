import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/entities/paginated_result.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filter.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/get_paginated_products.dart';
import '../../domain/usecases/get_product.dart';
import '../../domain/usecases/update_product.dart';

// `productsProvider` used to sit here - one unbounded `FutureProvider` over the
// whole product table. Nothing rendered it: the list and the POS grid both read
// `paginatedProductsProvider` below. What kept it alive was five
// `ref.invalidate(productsProvider)` calls in the edit, delete and bulk-action
// paths, all aimed at a provider no screen was watching.
//
// So saving a product refreshed nothing. In the split view, where the list and
// the detail panel are on screen together, an edit left the card behind it
// showing the old name and price until something unrelated rebuilt the list.
// Those calls now name the provider the list actually reads, and the unbounded
// fetch is gone with the provider.

/// Provider for a single product by ID
final productProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  final useCase = getIt<GetProduct>();
  final result = await useCase(GetProductParams(id: id));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (product) => product,
  );
});

// ===========================================
// PAGINATION PROVIDERS
//
// The list's filter, search, sort and page all live in one place -
// `productFilterProvider` - and are resolved server-side by
// `paginatedProductsProvider`.
//
// Six providers used to sit above this block: `searchQueryProvider`,
// `categoryFilterProvider`, `stockFilterProvider`, `sortOptionProvider`,
// `productSearchProvider` and `filteredProductsProvider`. They were the
// pre-pagination design - four separate pieces of filter state combined by a
// client-side filter-and-sort over the whole product table - and nothing
// rendered them any more. Their only remaining readers were the two selection
// providers, which is exactly how "select all" came to operate on a different
// result set from the one on screen. Those now read the paginated result, and
// these are gone.
// ===========================================

/// Unified product filter state provider with pagination
final productFilterProvider =
    StateNotifierProvider.autoDispose<ProductFilterNotifier, ProductFilter>(
  (ref) => ProductFilterNotifier(),
);

/// State notifier for managing product filter and pagination
class ProductFilterNotifier extends StateNotifier<ProductFilter> {
  ProductFilterNotifier() : super(const ProductFilter());

  /// Set search query (resets to page 1)
  void setSearchQuery(String? query) {
    final trimmedQuery = query?.trim();
    if (trimmedQuery == state.searchQuery) return;
    state = state
        .copyWith(
          searchQuery: trimmedQuery,
          clearSearchQuery: trimmedQuery == null || trimmedQuery.isEmpty,
        )
        .resetToFirstPage();
  }

  /// Set category filter (resets to page 1)
  void setCategoryId(String? categoryId) {
    if (categoryId == state.categoryId) return;
    state = state
        .copyWith(categoryId: categoryId, clearCategoryId: categoryId == null)
        .resetToFirstPage();
  }

  /// Set stock filter (resets to page 1)
  void setStockFilter(StockFilter filter) {
    if (filter == state.stockFilter) return;
    state = state.copyWith(stockFilter: filter).resetToFirstPage();
  }

  /// Set sort option (resets to page 1)
  void setSortOption(ProductSortOption option) {
    if (option == state.sortOption) return;
    state = state.copyWith(sortOption: option).resetToFirstPage();
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page < 1 || page == state.page) return;
    state = state.copyWith(page: page);
  }

  /// Go to next page
  void nextPage() {
    state = state.copyWith(page: state.page + 1);
  }

  /// Go to previous page
  void previousPage() {
    if (state.page > 1) {
      state = state.copyWith(page: state.page - 1);
    }
  }

  /// Reset all filters to default
  void resetFilters() {
    state = const ProductFilter();
  }
}

/// Provider for paginated products (reacts to filter changes)
final paginatedProductsProvider =
    FutureProvider.autoDispose<PaginatedResult<Product>>((ref) async {
  final filter = ref.watch(productFilterProvider);
  final useCase = getIt<GetPaginatedProducts>();
  final result = await useCase(filter);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (paginatedResult) => paginatedResult,
  );
});

/// Helper class for pagination display info
class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int startIndex;
  final int endIndex;
  final bool hasPrevious;
  final bool hasNext;

  const PaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.startIndex,
    required this.endIndex,
    required this.hasPrevious,
    required this.hasNext,
  });

  /// Display string like "1-8 dari 45 produk"
  String get displayText => totalCount == 0
      ? '0 produk'
      : '$startIndex-$endIndex dari $totalCount produk';
}

/// Provider for pagination info (convenience provider)
final paginationInfoProvider = Provider.autoDispose<PaginationInfo?>((ref) {
  return ref.watch(paginatedProductsProvider).maybeWhen(
        data: (result) => PaginationInfo(
          currentPage: result.currentPage,
          totalPages: result.totalPages,
          totalCount: result.totalCount,
          startIndex: result.startIndex,
          endIndex: result.endIndex,
          hasPrevious: result.hasPreviousPage,
          hasNext: result.hasNextPage,
        ),
        orElse: () => null,
      );
});

/// Form state for creating/updating products
class ProductFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const ProductFormState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  ProductFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return ProductFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Notifier for product form operations
class ProductFormNotifier extends StateNotifier<ProductFormState> {
  ProductFormNotifier() : super(const ProductFormState());

  Future<void> createProduct(CreateProductParams params) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final useCase = getIt<CreateProduct>();
    final result = await useCase(params);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
      (product) {
        state = state.copyWith(isLoading: false, isSuccess: true);
      },
    );
  }

  Future<void> updateProduct(Product product) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final useCase = getIt<UpdateProduct>();
    final result = await useCase(product);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
      (updatedProduct) {
        state = state.copyWith(isLoading: false, isSuccess: true);
      },
    );
  }

  Future<void> deleteProduct(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final useCase = getIt<DeleteProduct>();
    final result = await useCase(DeleteProductParams(id: id));

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
      (_) {
        state = state.copyWith(isLoading: false, isSuccess: true);
      },
    );
  }

  void resetState() {
    state = const ProductFormState();
  }
}

/// Provider for product form state
final productFormProvider =
    StateNotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>(
  (ref) => ProductFormNotifier(),
);
