import '../../domain/entities/transaction_item.dart';

/// Data Transfer Object for TransactionItem
/// Handles conversion between Supabase JSON and TransactionItem entity
class TransactionItemModel {
  final String id;
  final String transactionId;
  final String productId;
  final String productName;
  final String productSku;
  final int quantity;
  final double costPrice;
  final double sellingPrice;
  final double discountAmount;
  final double subtotal;
  final DateTime createdAt;

  const TransactionItemModel({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    required this.discountAmount,
    required this.subtotal,
    required this.createdAt,
  });

  /// Create TransactionItemModel from Supabase JSON
  factory TransactionItemModel.fromJson(Map<String, dynamic> json) {
    return TransactionItemModel(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String,
      quantity: json['quantity'] as int,
      costPrice: (json['cost_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert TransactionItemModel to Supabase JSON (for insert)
  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'product_sku': productSku,
      'quantity': quantity,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'discount_amount': discountAmount,
      'subtotal': subtotal,
    };
  }

  /// Convert TransactionItemModel to TransactionItem entity
  TransactionItem toEntity() {
    return TransactionItem(
      id: id,
      transactionId: transactionId,
      productId: productId,
      productName: productName,
      productSku: productSku,
      quantity: quantity,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      discountAmount: discountAmount,
      subtotal: subtotal,
      createdAt: createdAt,
    );
  }

  /// Create TransactionItemModel from TransactionItem entity
  factory TransactionItemModel.fromEntity(TransactionItem item) {
    return TransactionItemModel(
      id: item.id,
      transactionId: item.transactionId,
      productId: item.productId,
      productName: item.productName,
      productSku: item.productSku,
      quantity: item.quantity,
      costPrice: item.costPrice,
      sellingPrice: item.sellingPrice,
      discountAmount: item.discountAmount,
      subtotal: item.subtotal,
      createdAt: item.createdAt,
    );
  }
}
