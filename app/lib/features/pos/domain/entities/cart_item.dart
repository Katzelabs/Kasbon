import 'package:equatable/equatable.dart';

import '../../../products/domain/entities/product.dart';

/// CartItem entity representing an item in the shopping cart
///
/// Contains a reference to the [Product] and the quantity selected.
/// Provides computed properties for subtotal and profit calculations.
class CartItem extends Equatable {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  /// Subtotal for this cart item (selling price * quantity)
  double get subtotal => product.sellingPrice * quantity;

  /// Profit for this cart item ((selling price - cost price) * quantity)
  double get profit => (product.sellingPrice - product.costPrice) * quantity;

  /// Check if the quantity exceeds available stock
  /// Used to show warnings (but not block sales per MVP requirements)
  bool get exceedsStock => quantity > product.stock;

  /// Check if stock is low after this sale
  bool get wouldCauseLowStock =>
      product.stock - quantity <= product.minStock && product.stock - quantity > 0;

  /// Check if this sale would cause out of stock
  bool get wouldCauseOutOfStock => product.stock - quantity <= 0;

  /// Create a copy with updated fields
  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [product.id, quantity];

  @override
  String toString() =>
      'CartItem(product: ${product.name}, quantity: $quantity, subtotal: $subtotal)';
}
