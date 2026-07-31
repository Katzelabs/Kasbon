import 'package:equatable/equatable.dart';

import 'transaction_item.dart';

/// Payment method enum for transactions
enum PaymentMethod {
  cash,
  transfer,
  qris,
  debt;

  /// Get display label in Bahasa Indonesia
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tunai';
      case PaymentMethod.transfer:
        return 'Transfer';
      case PaymentMethod.qris:
        return 'QRIS';
      case PaymentMethod.debt:
        return 'Hutang';
    }
  }

  /// Convert from string stored in database
  static PaymentMethod fromString(String value) {
    switch (value.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'transfer':
        return PaymentMethod.transfer;
      case 'qris':
        return PaymentMethod.qris;
      case 'debt':
        return PaymentMethod.debt;
      default:
        return PaymentMethod.cash;
    }
  }
}

/// Payment status enum for transactions
enum PaymentStatus {
  paid,
  debt;

  /// Get display label in Bahasa Indonesia
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Lunas';
      case PaymentStatus.debt:
        return 'Hutang';
    }
  }

  /// Convert from string stored in database
  static PaymentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'debt':
        return PaymentStatus.debt;
      default:
        return PaymentStatus.paid;
    }
  }
}

/// What affirmed that the money for a transaction actually arrived.
///
/// Only [cashier] is ever written today. A QRIS sale on a printed sticker has
/// no API behind it, so the confirmation is a human looking at the customer's
/// phone and tapping a button - which is evidence, not verification, and worth
/// being able to tell apart from the other two later.
///
/// The other values are named now, before there are rows to migrate, so the
/// vocabulary is fixed: [notification] for a merchant-app push read off the
/// device, [webhook] for a real payment gateway calling us.
enum PaymentConfirmedBy {
  cashier,
  notification,
  webhook;

  /// Get display label in Bahasa Indonesia
  String get label {
    switch (this) {
      case PaymentConfirmedBy.cashier:
        return 'Kasir';
      case PaymentConfirmedBy.notification:
        return 'Notifikasi';
      case PaymentConfirmedBy.webhook:
        return 'Otomatis';
    }
  }

  /// Convert from string stored in database, or null when absent.
  ///
  /// Unlike the other enums here there is no sensible default: a row with no
  /// confirmation is a real state (every cash sale), and inventing 'cashier'
  /// for it would claim a person vouched for money nobody was asked about.
  static PaymentConfirmedBy? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'cashier':
        return PaymentConfirmedBy.cashier;
      case 'notification':
        return PaymentConfirmedBy.notification;
      case 'webhook':
        return PaymentConfirmedBy.webhook;
      default:
        return null;
    }
  }
}

/// Transaction entity representing a complete sales transaction
///
/// Contains header information about the sale as well as a list of
/// [TransactionItem] line items.
class Transaction extends Equatable {
  final String id;

  /// Unique transaction number in format TRX-YYYYMMDD-XXXX
  final String transactionNumber;

  /// Optional customer name (required for debt transactions)
  final String? customerName;

  /// Sum of all line item subtotals before discount/tax
  final double subtotal;

  /// Fixed discount amount applied to total
  final double discountAmount;

  /// Percentage discount (0-100)
  final double discountPercentage;

  /// Tax amount
  final double taxAmount;

  /// Final total (subtotal - discount + tax)
  final double total;

  /// How the customer paid
  final PaymentMethod paymentMethod;

  /// Whether the transaction is paid or debt
  final PaymentStatus paymentStatus;

  /// Amount of cash received from customer
  final double? cashReceived;

  /// Change to give back to customer
  final double? cashChange;

  /// Optional notes for the transaction
  final String? notes;

  /// Name of cashier who processed the transaction
  final String? cashierName;

  /// When the transaction occurred
  final DateTime transactionDate;

  /// When the debt was paid (for debt transactions)
  final DateTime? debtPaidAt;

  /// Object path of the payment proof photo inside the `payment-proofs`
  /// bucket, or null when no photo was taken.
  ///
  /// A path, never a URL - the bucket is private, so a viewable link has to be
  /// signed at render time. Resolve through `PaymentProofStorage.signedUrlFor`.
  final String? paymentProofPath;

  /// When the money was affirmed to have arrived.
  ///
  /// Null for cash, where handing over notes is its own confirmation. Distinct
  /// from [transactionDate], which is when the sale happened: the two are the
  /// same instant today and will not be once a webhook can confirm a sale after
  /// the customer has left.
  final DateTime? paymentConfirmedAt;

  /// What did the confirming, or null if nothing did.
  final PaymentConfirmedBy? paymentConfirmedBy;

  /// Gateway-side identifier (RRN, order id).
  ///
  /// Always null today - a QRIS sticker has no gateway behind it to issue one.
  /// The field exists so adding dynamic QRIS later is an Edge Function and not
  /// a migration against a live shop's data.
  final String? paymentReference;

  /// Record creation timestamp
  final DateTime createdAt;

  /// Record update timestamp
  final DateTime updatedAt;

  /// Line items in this transaction
  final List<TransactionItem> items;

  const Transaction({
    required this.id,
    required this.transactionNumber,
    this.customerName,
    required this.subtotal,
    this.discountAmount = 0,
    this.discountPercentage = 0,
    this.taxAmount = 0,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.cashReceived,
    this.cashChange,
    this.notes,
    this.cashierName,
    required this.transactionDate,
    this.debtPaidAt,
    this.paymentProofPath,
    this.paymentConfirmedAt,
    this.paymentConfirmedBy,
    this.paymentReference,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  /// Calculate total profit from all items
  double get totalProfit =>
      items.fold(0.0, (sum, item) => sum + item.profit);

  /// Total number of items in transaction
  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

  /// Number of unique products in transaction
  int get uniqueItemCount => items.length;

  /// Check if transaction is paid
  bool get isPaid => paymentStatus == PaymentStatus.paid;

  /// Check if transaction is debt
  bool get isDebt => paymentStatus == PaymentStatus.debt;

  /// Check if debt has been settled
  bool get isDebtSettled => isDebt && debtPaidAt != null;

  /// Whether a photo backs this payment.
  bool get hasPaymentProof =>
      paymentProofPath != null && paymentProofPath!.isNotEmpty;

  /// A non-cash sale whose payment nobody has affirmed.
  ///
  /// Not an error state: a cashier can take a QRIS payment and skip the photo,
  /// or lose the upload to a flat warung connection. It is the state that earns
  /// an "attach the proof" affordance on the transaction detail screen, so the
  /// evidence can be added after the queue clears.
  bool get awaitsPaymentConfirmation =>
      paymentMethod == PaymentMethod.qris && paymentConfirmedAt == null;

  /// Create a copy with updated fields
  Transaction copyWith({
    String? id,
    String? transactionNumber,
    String? customerName,
    double? subtotal,
    double? discountAmount,
    double? discountPercentage,
    double? taxAmount,
    double? total,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    double? cashReceived,
    double? cashChange,
    String? notes,
    String? cashierName,
    DateTime? transactionDate,
    DateTime? debtPaidAt,
    String? paymentProofPath,
    DateTime? paymentConfirmedAt,
    PaymentConfirmedBy? paymentConfirmedBy,
    String? paymentReference,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TransactionItem>? items,
  }) {
    return Transaction(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      customerName: customerName ?? this.customerName,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      cashReceived: cashReceived ?? this.cashReceived,
      cashChange: cashChange ?? this.cashChange,
      notes: notes ?? this.notes,
      cashierName: cashierName ?? this.cashierName,
      transactionDate: transactionDate ?? this.transactionDate,
      debtPaidAt: debtPaidAt ?? this.debtPaidAt,
      paymentProofPath: paymentProofPath ?? this.paymentProofPath,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      paymentConfirmedBy: paymentConfirmedBy ?? this.paymentConfirmedBy,
      paymentReference: paymentReference ?? this.paymentReference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [id, transactionNumber];

  @override
  String toString() =>
      'Transaction(id: $id, number: $transactionNumber, total: $total, status: ${paymentStatus.label})';
}
