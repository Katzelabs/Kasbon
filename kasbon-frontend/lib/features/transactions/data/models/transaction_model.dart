import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_item.dart';

/// Data Transfer Object for Transaction
/// Handles conversion between Supabase JSON and Transaction entity
class TransactionModel {
  final String id;
  final String transactionNumber;
  final String? customerName;
  final double subtotal;
  final double discountAmount;
  final double discountPercentage;
  final double taxAmount;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final double? cashReceived;
  final double? cashChange;
  final String? notes;
  final String? cashierName;
  final DateTime transactionDate;
  final DateTime? debtPaidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.transactionNumber,
    this.customerName,
    required this.subtotal,
    required this.discountAmount,
    required this.discountPercentage,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.cashReceived,
    this.cashChange,
    this.notes,
    this.cashierName,
    required this.transactionDate,
    this.debtPaidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create TransactionModel from Supabase JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      transactionNumber: json['transaction_number'] as String,
      customerName: json['customer_name'] as String?,
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount:
          (json['discount_amount'] as num?)?.toDouble() ?? 0,
      discountPercentage:
          (json['discount_percentage'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String,
      cashReceived: (json['cash_received'] as num?)?.toDouble(),
      cashChange: (json['cash_change'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      cashierName: json['cashier_name'] as String?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      debtPaidAt: json['debt_paid_at'] != null
          ? DateTime.parse(json['debt_paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert TransactionModel to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'transaction_number': transactionNumber,
      'customer_name': customerName,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'discount_percentage': discountPercentage,
      'tax_amount': taxAmount,
      'total': total,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'cash_received': cashReceived,
      'cash_change': cashChange,
      'notes': notes,
      'cashier_name': cashierName,
      'transaction_date': transactionDate.toIso8601String(),
      'debt_paid_at': debtPaidAt?.toIso8601String(),
    };
  }

  /// Convert TransactionModel to Transaction entity
  Transaction toEntity({List<TransactionItem> items = const []}) {
    return Transaction(
      id: id,
      transactionNumber: transactionNumber,
      customerName: customerName,
      subtotal: subtotal,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      taxAmount: taxAmount,
      total: total,
      paymentMethod: PaymentMethod.fromString(paymentMethod),
      paymentStatus: PaymentStatus.fromString(paymentStatus),
      cashReceived: cashReceived,
      cashChange: cashChange,
      notes: notes,
      cashierName: cashierName,
      transactionDate: transactionDate,
      debtPaidAt: debtPaidAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items,
    );
  }

  /// Create TransactionModel from Transaction entity
  factory TransactionModel.fromEntity(Transaction transaction) {
    return TransactionModel(
      id: transaction.id,
      transactionNumber: transaction.transactionNumber,
      customerName: transaction.customerName,
      subtotal: transaction.subtotal,
      discountAmount: transaction.discountAmount,
      discountPercentage: transaction.discountPercentage,
      taxAmount: transaction.taxAmount,
      total: transaction.total,
      paymentMethod: transaction.paymentMethod.name,
      paymentStatus: transaction.paymentStatus.name,
      cashReceived: transaction.cashReceived,
      cashChange: transaction.cashChange,
      notes: transaction.notes,
      cashierName: transaction.cashierName,
      transactionDate: transaction.transactionDate,
      debtPaidAt: transaction.debtPaidAt,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
    );
  }
}
