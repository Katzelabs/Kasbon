import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/usecases/get_all_products.dart';
import '../../../products/domain/usecases/search_products.dart';

/// Search query state provider
final posSearchQueryProvider = StateProvider<String>((ref) => '');

/// Selected category filter provider (null = all categories)
final posCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Debounced search results provider
///
/// Returns all active products when search is empty,
/// otherwise returns products matching the search query.
/// Implements 300ms debounce to avoid excessive database queries.
final posSearchResultsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final query = ref.watch(posSearchQueryProvider);
  final categoryFilter = ref.watch(posCategoryFilterProvider);

  // Wait for debounce delay
  await Future.delayed(const Duration(milliseconds: 300));

  // Check if the query changed during debounce
  if (ref.read(posSearchQueryProvider) != query) {
    throw Exception('Cancelled');
  }

  List<Product> products;

  if (query.isEmpty) {
    // Return all active products
    final useCase = getIt<GetAllProducts>();
    final result = await useCase();
    products = result.fold(
      (failure) => throw Exception(failure.message),
      (productList) => productList,
    );
  } else {
    // Search by query
    final useCase = getIt<SearchProducts>();
    final result = await useCase(SearchProductsParams(query: query));
    products = result.fold(
      (failure) => throw Exception(failure.message),
      (productList) => productList,
    );
  }

  // Apply category filter if selected
  if (categoryFilter != null) {
    products = products
        .where((product) => product.categoryId == categoryFilter)
        .toList();
  }

  return products;
});

/// Provider for getting products by category (without search)
final productsByCategoryProvider =
    FutureProvider.autoDispose.family<List<Product>, String?>((ref, categoryId) async {
  final useCase = getIt<GetAllProducts>();
  final result = await useCase();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) {
      if (categoryId == null) return products;
      return products
          .where((product) => product.categoryId == categoryId)
          .toList();
    },
  );
});
