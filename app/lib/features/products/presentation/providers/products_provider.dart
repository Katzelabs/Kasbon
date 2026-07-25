import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/entities/paginated_result.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filter.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/get_all_products.dart';
import '../../domain/usecases/get_paginated_products.dart';
import '../../domain/usecases/get_product.dart';
import '../../domain/usecases/search_products.dart';
import '../../domain/usecases/update_product.dart';

/// Provider for all products
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final useCase = getIt<GetAllProducts>();
  final result = await useCase();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

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

/// Provider for search query state
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Provider for category filter state (null = all categories)
final categoryFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Provider for stock filter state
final stockFilterProvider =
    StateProvider.autoDispose<StockFilter>((ref) => StockFilter.all);

/// Provider for sort option state
final sortOptionProvider = StateProvider.autoDispose<ProductSortOption>(
    (ref) => ProductSortOption.nameAsc);

/// Provider for search results
final productSearchProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  if (query.isEmpty) {
    return [];
  }
  final useCase = getIt<SearchProducts>();
  final result = await useCase(SearchProductsParams(query: query));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
});

/// Provider for filtered products (combines search, category, stock, and sort filters)
final filteredProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final categoryId = ref.watch(categoryFilterProvider);
  final stockFilter = ref.watch(stockFilterProvider);
  final sortOption = ref.watch(sortOptionProvider);

  // Get base product list (from search or all products)
  List<Product> products;
  if (query.isNotEmpty) {
    products = ref.watch(productSearchProvider(query)).maybeWhen(
          data: (p) => p,
          orElse: () => [],
        );
  } else {
    products = ref.watch(productsProvider).maybeWhen(
          data: (p) => p,
          orElse: () => [],
        );
  }

  // Apply category filter
  if (categoryId != null) {
    products = products.where((p) => p.categoryId == categoryId).toList();
  }

  // Apply stock filter
  switch (stockFilter) {
    case StockFilter.available:
      products = products.where((p) => p.stock > p.minStock).toList();
      break;
    case StockFilter.lowStock:
      products = products.where((p) => p.isLowStock).toList();
      break;
    case StockFilter.outOfStock:
      products = products.where((p) => p.isOutOfStock).toList();
      break;
    case StockFilter.all:
      // No filter
      break;
  }

  // Apply sorting
  switch (sortOption) {
    case ProductSortOption.nameAsc:
      products.sort((a, b) => a.name.compareTo(b.name));
      break;
    case ProductSortOption.nameDesc:
      products.sort((a, b) => b.name.compareTo(a.name));
      break;
    case ProductSortOption.priceAsc:
      products.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
      break;
    case ProductSortOption.priceDesc:
      products.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
      break;
    case ProductSortOption.stockAsc:
      products.sort((a, b) => a.stock.compareTo(b.stock));
      break;
    case ProductSortOption.stockDesc:
      products.sort((a, b) => b.stock.compareTo(a.stock));
      break;
  }

  return products;
});

// ===========================================
// PAGINATION PROVIDERS
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
