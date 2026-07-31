import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../pos/domain/entities/cart_item.dart';
import '../entities/transaction.dart';
import '../entities/transaction_item.dart';
import '../repositories/transaction_repository.dart';

/// Use case to create a new transaction from cart items
///
/// This use case:
/// 1. Validates cart is not empty
/// 2. Generates a unique transaction number (TRX-YYYYMMDD-XXXX)
/// 3. Creates the transaction and all its items
/// 4. Updates product stock (handled by repository)
class CreateTransaction implements UseCase<Transaction, CreateTransactionParams> {
  final TransactionRepository _repository;

  CreateTransaction(this._repository);

  @override
  Future<Either<Failure, Transaction>> call(CreateTransactionParams params) async {
    // 1. Validate cart is not empty
    if (params.cartItems.isEmpty) {
      return const Left(
        ValidationFailure(message: 'Keranjang tidak boleh kosong'),
      );
    }

    // 2. Generate transaction number
    final transactionNumberResult = await _generateTransactionNumber();

    return transactionNumberResult.fold(
      (failure) => Left(failure),
      (transactionNumber) async {
        // 3. Calculate totals
        final subtotal = params.cartItems.fold(
          0.0,
          (sum, item) => sum + item.subtotal,
        );
        final total = subtotal; // MVP: no discount/tax

        // Determine payment method and status
        final paymentMethod = params.paymentMethod;
        final paymentStatus = params.paymentStatus;

        // Cash fields belong to cash sales only.
        //
        // Keyed on "is this cash" rather than the old "is this debt": every
        // non-cash method has no notes changing hands, so a QRIS or transfer
        // sale storing `cash_change = 0 - total` would record a negative
        // kembalian for money the cashier never took. Debt was the only
        // non-cash method when this was written, which is why the inverted
        // test survived.
        final isCash = paymentMethod == PaymentMethod.cash;
        final double? cashReceived = isCash ? params.cashReceived : null;
        final double? cashChange =
            isCash ? (params.cashReceived ?? 0) - total : null;

        // 4. Create Transaction entity
        final now = DateTime.now();
        final transactionId = const Uuid().v4();

        final transaction = Transaction(
          id: transactionId,
          transactionNumber: transactionNumber,
          customerName: params.customerName,
          subtotal: subtotal,
          discountAmount: 0,
          discountPercentage: 0,
          taxAmount: 0,
          total: total,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
          cashReceived: cashReceived,
          cashChange: cashChange,
          notes: params.notes,
          cashierName: params.cashierName,
          transactionDate: now,
          paymentConfirmedAt: params.paymentConfirmedAt,
          paymentConfirmedBy: params.paymentConfirmedBy,
          createdAt: now,
          updatedAt: now,
        );

        // 5. Convert CartItems to TransactionItems (snapshot prices)
        final transactionItems = params.cartItems.map((cartItem) {
          return TransactionItem(
            id: const Uuid().v4(),
            transactionId: transactionId,
            productId: cartItem.product.id,
            productName: cartItem.product.name,
            productSku: cartItem.product.sku,
            quantity: cartItem.quantity,
            costPrice: cartItem.product.costPrice,
            sellingPrice: cartItem.product.sellingPrice,
            discountAmount: 0,
            subtotal: cartItem.subtotal,
            createdAt: now,
          );
        }).toList();

        // 6. Create transaction via repository
        return _repository.createTransaction(transaction, transactionItems);
      },
    );
  }

  /// Generate a unique transaction number in format TRX-YYYYMMDD-XXXX
  Future<Either<Failure, String>> _generateTransactionNumber() async {
    final countResult = await _repository.getTodayTransactionCount();

    return countResult.fold(
      (failure) => Left(failure),
      (count) {
        final now = DateTime.now();
        final dateStr = '${now.year}'
            '${now.month.toString().padLeft(2, '0')}'
            '${now.day.toString().padLeft(2, '0')}';
        final sequence = (count + 1).toString().padLeft(4, '0');
        return Right('TRX-$dateStr-$sequence');
      },
    );
  }
}

/// Parameters for CreateTransaction use case
class CreateTransactionParams extends Equatable {
  /// List of items in the cart
  final List<CartItem> cartItems;

  /// Amount of cash received from customer (required for cash payments, null for debt)
  final double? cashReceived;

  /// Optional customer name (required for debt transactions)
  final String? customerName;

  /// Optional notes for the transaction
  final String? notes;

  /// Optional cashier name (can be from settings)
  final String? cashierName;

  /// Payment method (default: cash)
  final PaymentMethod paymentMethod;

  /// Payment status (default: paid)
  final PaymentStatus paymentStatus;

  /// When the money was affirmed to have arrived, for methods where that is a
  /// separate act from the sale. Null for cash.
  final DateTime? paymentConfirmedAt;

  /// What affirmed it. Null for cash.
  final PaymentConfirmedBy? paymentConfirmedBy;

  const CreateTransactionParams({
    required this.cartItems,
    this.cashReceived,
    this.customerName,
    this.notes,
    this.cashierName,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.paid,
    this.paymentConfirmedAt,
    this.paymentConfirmedBy,
  });

  /// Factory for cash payment
  factory CreateTransactionParams.cash({
    required List<CartItem> cartItems,
    required double cashReceived,
    String? customerName,
    String? notes,
    String? cashierName,
  }) {
    return CreateTransactionParams(
      cartItems: cartItems,
      cashReceived: cashReceived,
      customerName: customerName,
      notes: notes,
      cashierName: cashierName,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
    );
  }

  /// Factory for a QRIS payment taken on a printed sticker.
  ///
  /// No cash and no change: the customer paid their own phone, so there is
  /// nothing to hand back. No amount either - on QRIS statis the customer types
  /// the total themselves, and this app never sees what they typed.
  ///
  /// [confirmedAt] is the moment the cashier looked at the customer's success
  /// screen and said yes. It is required rather than optional because a QRIS
  /// sale reaching this factory has, by definition, already been confirmed by a
  /// human - the button that creates it is the confirmation. A QRIS row with no
  /// confirmation would mean the app took money on nobody's word.
  ///
  /// The proof photo is not here. It is uploaded after the sale commits and
  /// attached by [AttachPaymentProof], because a slow upload must never hold up
  /// a queue at the counter.
  factory CreateTransactionParams.qris({
    required List<CartItem> cartItems,
    required DateTime confirmedAt,
    PaymentConfirmedBy confirmedBy = PaymentConfirmedBy.cashier,
    String? customerName,
    String? notes,
    String? cashierName,
  }) {
    return CreateTransactionParams(
      cartItems: cartItems,
      cashReceived: null,
      customerName: customerName,
      notes: notes,
      cashierName: cashierName,
      paymentMethod: PaymentMethod.qris,
      paymentStatus: PaymentStatus.paid,
      paymentConfirmedAt: confirmedAt,
      paymentConfirmedBy: confirmedBy,
    );
  }

  /// Factory for debt payment
  factory CreateTransactionParams.debt({
    required List<CartItem> cartItems,
    required String customerName,
    String? notes,
    String? cashierName,
  }) {
    return CreateTransactionParams(
      cartItems: cartItems,
      cashReceived: null,
      customerName: customerName,
      notes: notes,
      cashierName: cashierName,
      paymentMethod: PaymentMethod.debt,
      paymentStatus: PaymentStatus.debt,
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        cashReceived,
        customerName,
        notes,
        cashierName,
        paymentMethod,
        paymentStatus,
        paymentConfirmedAt,
        paymentConfirmedBy,
      ];
}
