import 'package:equatable/equatable.dart';

/// TransactionItem entity representing a line item in a transaction
///
/// Stores snapshot of product data at the time of transaction to preserve
/// historical accuracy even if product prices change later.
class TransactionItem extends Equatable {
  final String id;
  final String transactionId;
  final String productId;

  /// Snapshot of product name at transaction time
  final String productName;

  /// Snapshot of product SKU at transaction time
  final String productSku;

  /// Quantity sold
  final int quantity;

  /// Snapshot of cost price at transaction time (for profit calculation)
  final double costPrice;

  /// Snapshot of selling price at transaction time
  final double sellingPrice;

  /// Discount applied to this item
  final double discountAmount;

  /// Line item subtotal (sellingPrice * quantity - discountAmount)
  final double subtotal;

  /// When this item was created
  final DateTime createdAt;

  const TransactionItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    this.discountAmount = 0,
    required this.subtotal,
    required this.createdAt,
  });

  /// Calculate profit for this line item
  /// profit = (sellingPrice - costPrice) * quantity - discountAmount
  double get profit =>
      (sellingPrice - costPrice) * quantity - discountAmount;

  /// Create a copy with updated fields
  TransactionItem copyWith({
    String? id,
    String? transactionId,
    String? productId,
    String? productName,
    String? productSku,
    int? quantity,
    double? costPrice,
    double? sellingPrice,
    double? discountAmount,
    double? subtotal,
    DateTime? createdAt,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      subtotal: subtotal ?? this.subtotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, transactionId, productId];

  @override
  String toString() =>
      'TransactionItem(id: $id, productName: $productName, qty: $quantity, subtotal: $subtotal)';
}
