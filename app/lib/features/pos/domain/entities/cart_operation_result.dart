/// Result of a cart operation (add, update quantity, etc.)
enum CartOperationResult {
  /// Operation was successful
  success,

  /// Product has zero stock - cannot add to cart
  outOfStock,

  /// Requested quantity exceeds available stock
  exceedsStock,
}

/// Response from a cart operation with result and additional data
class CartOperationResponse {
  final CartOperationResult result;
  final int? availableStock;
  final String? productName;
  final String? unit;

  const CartOperationResponse({
    required this.result,
    this.availableStock,
    this.productName,
    this.unit,
  });

  /// Check if the operation was successful
  bool get isSuccess => result == CartOperationResult.success;
}
