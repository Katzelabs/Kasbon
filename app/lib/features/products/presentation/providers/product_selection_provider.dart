import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import 'products_provider.dart';

/// Enum for product list view mode
enum ProductViewMode {
  grid,
  table,
}

/// Provider for view mode preference
final productViewModeProvider = StateProvider<ProductViewMode>((ref) {
  return ProductViewMode.grid;
});

/// Notifier for managing product selection state
class ProductSelectionNotifier extends StateNotifier<Set<String>> {
  ProductSelectionNotifier() : super({});

  void toggleSelection(String id) {
    if (state.contains(id)) {
      state = Set.from(state)..remove(id);
    } else {
      state = Set.from(state)..add(id);
    }
  }

  void select(String id) {
    if (!state.contains(id)) {
      state = Set.from(state)..add(id);
    }
  }

  void deselect(String id) {
    if (state.contains(id)) {
      state = Set.from(state)..remove(id);
    }
  }

  void selectAll(List<String> ids) {
    state = Set.from(ids);
  }

  void clearSelection() {
    state = {};
  }

  void selectMultiple(List<String> ids) {
    state = Set.from(state)..addAll(ids);
  }

  void deselectMultiple(List<String> ids) {
    state = Set.from(state)..removeAll(ids);
  }

  bool isSelected(String id) => state.contains(id);

  bool get hasSelection => state.isNotEmpty;

  int get selectionCount => state.length;
}

/// Provider for selection notifier
final productSelectionProvider =
    StateNotifierProvider<ProductSelectionNotifier, Set<String>>((ref) {
  return ProductSelectionNotifier();
});

/// Derived provider for checking if all visible products are selected
final allProductsSelectedProvider = Provider<bool>((ref) {
  final selectedIds = ref.watch(productSelectionProvider);
  final productsAsync = ref.watch(filteredProductsProvider);

  return productsAsync.maybeWhen(
    data: (products) {
      if (products.isEmpty) return false;
      return products.every((p) => selectedIds.contains(p.id));
    },
    orElse: () => false,
  );
});

/// Provider for selected products (full entities)
final selectedProductsProvider = Provider<List<Product>>((ref) {
  final selectedIds = ref.watch(productSelectionProvider);
  final productsAsync = ref.watch(filteredProductsProvider);

  return productsAsync.maybeWhen(
    data: (products) =>
        products.where((p) => selectedIds.contains(p.id)).toList(),
    orElse: () => [],
  );
});

/// Provider for selection count
final selectionCountProvider = Provider<int>((ref) {
  return ref.watch(productSelectionProvider).length;
});
