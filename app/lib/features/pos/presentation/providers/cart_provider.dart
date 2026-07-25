import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../products/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_operation_result.dart';

/// Cart state notifier for managing shopping cart
///
/// Provides methods to add, remove, and update cart items.
/// Cart state persists during POS session only (not across app restart).
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Add a product to cart with stock validation
  ///
  /// If the product already exists in cart, increments its quantity.
  /// Otherwise, adds a new cart item with quantity 1.
  ///
  /// Returns [CartOperationResponse] indicating success or failure reason.
  /// If product is out of stock, returns [CartOperationResult.outOfStock].
  /// If adding would exceed stock, returns [CartOperationResult.exceedsStock].
  CartOperationResponse addProduct(Product product) {
    // Check if product is completely out of stock
    if (product.isOutOfStock) {
      return CartOperationResponse(
        result: CartOperationResult.outOfStock,
        productName: product.name,
        availableStock: 0,
        unit: product.unit,
      );
    }

    // Calculate current quantity in cart
    final currentQuantity = getQuantity(product.id);
    final availableToAdd = product.stock - currentQuantity;

    // Check if we can add one more
    if (availableToAdd <= 0) {
      return CartOperationResponse(
        result: CartOperationResult.exceedsStock,
        productName: product.name,
        availableStock: product.stock,
        unit: product.unit,
      );
    }

    // Proceed with adding
    final existingIndex = state.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Product exists - increment quantity
      final existing = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(quantity: existing.quantity + 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // New product - add to cart
      state = [...state, CartItem(product: product, quantity: 1)];
    }

    return const CartOperationResponse(result: CartOperationResult.success);
  }

  /// Update quantity for a specific product with stock validation
  ///
  /// If quantity is 0 or less, removes the product from cart.
  /// Returns [CartOperationResponse] indicating success or failure.
  CartOperationResponse updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return const CartOperationResponse(result: CartOperationResult.success);
    }

    final itemIndex = state.indexWhere((i) => i.product.id == productId);
    if (itemIndex < 0) {
      return const CartOperationResponse(result: CartOperationResult.success);
    }

    final item = state[itemIndex];
    final product = item.product;

    // Validate against stock
    if (quantity > product.stock) {
      return CartOperationResponse(
        result: CartOperationResult.exceedsStock,
        productName: product.name,
        availableStock: product.stock,
        unit: product.unit,
      );
    }

    state = state.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    return const CartOperationResponse(result: CartOperationResult.success);
  }

  /// Increment quantity by 1 with stock validation
  CartOperationResponse incrementQuantity(String productId) {
    final index = state.indexWhere((i) => i.product.id == productId);
    if (index < 0) {
      return const CartOperationResponse(result: CartOperationResult.success);
    }

    final item = state[index];
    return updateQuantity(productId, item.quantity + 1);
  }

  /// Decrement quantity by 1
  ///
  /// If quantity becomes 0, removes the product from cart.
  void decrementQuantity(String productId) {
    final item = state.firstWhere(
      (i) => i.product.id == productId,
      orElse: () => throw Exception('Product not in cart'),
    );
    updateQuantity(productId, item.quantity - 1);
  }

  /// Remove a product from cart
  void removeProduct(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  /// Clear the entire cart
  void clear() {
    state = [];
  }

  /// Check if a product is in the cart
  bool containsProduct(String productId) {
    return state.any((item) => item.product.id == productId);
  }

  /// Get the quantity of a specific product in cart
  /// Returns 0 if product is not in cart
  int getQuantity(String productId) {
    final index = state.indexWhere((i) => i.product.id == productId);
    if (index < 0) return 0;
    return state[index].quantity;
  }
}

/// Main cart provider
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/// Derived provider: total item count (sum of all quantities)
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

/// Derived provider: number of unique products in cart
final cartUniqueItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.length;
});

/// Derived provider: cart subtotal (before any discount/tax)
final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.subtotal);
});

/// Derived provider: cart total (MVP: same as subtotal, no discount/tax)
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider);
});

/// Derived provider: total profit from cart items
final cartProfitProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.profit);
});

/// Derived provider: check if cart is empty
final cartIsEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});

/// Derived provider: check if any item exceeds available stock
final cartHasStockWarningProvider = Provider<bool>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.any((item) => item.exceedsStock);
});

/// Derived provider: list of items that exceed stock
final cartItemsWithStockWarningProvider = Provider<List<CartItem>>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.where((item) => item.exceedsStock).toList();
});
