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
        final isDebt = paymentMethod == PaymentMethod.debt;

        // For debt transactions, cash fields are null; otherwise calculate change
        final double? cashReceived = isDebt ? null : params.cashReceived;
        final double? cashChange =
            isDebt ? null : (params.cashReceived ?? 0) - total;

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

  const CreateTransactionParams({
    required this.cartItems,
    this.cashReceived,
    this.customerName,
    this.notes,
    this.cashierName,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.paid,
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
      ];
}
