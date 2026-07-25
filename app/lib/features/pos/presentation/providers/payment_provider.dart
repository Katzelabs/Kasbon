import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/create_transaction.dart';
import 'cart_provider.dart';

/// Selected payment method for the current transaction
enum SelectedPaymentMethod {
  cash,
  debt;

  String get label {
    switch (this) {
      case SelectedPaymentMethod.cash:
        return 'Tunai';
      case SelectedPaymentMethod.debt:
        return 'Hutang';
    }
  }
}

/// Payment state for tracking payment processing
class PaymentState {
  /// Whether payment is being processed
  final bool isProcessing;

  /// Error message if payment failed
  final String? errorMessage;

  /// The completed transaction after successful payment
  final Transaction? completedTransaction;

  const PaymentState({
    this.isProcessing = false,
    this.errorMessage,
    this.completedTransaction,
  });

  /// Check if payment was successful
  bool get isSuccess => completedTransaction != null;

  /// Check if there was an error
  bool get hasError => errorMessage != null;

  /// Create a copy with updated fields
  PaymentState copyWith({
    bool? isProcessing,
    String? errorMessage,
    Transaction? completedTransaction,
  }) {
    return PaymentState(
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
      completedTransaction: completedTransaction ?? this.completedTransaction,
    );
  }
}

/// Payment state notifier for processing payments
class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref _ref;

  PaymentNotifier(this._ref) : super(const PaymentState());

  /// Process a cash payment
  ///
  /// Takes the cash received amount, creates a transaction,
  /// and clears the cart on success.
  Future<void> processCashPayment({
    required double cashReceived,
    String? customerName,
    String? notes,
  }) async {
    // Set processing state
    state = const PaymentState(isProcessing: true);

    // Get cart items
    final cart = _ref.read(cartProvider);

    if (cart.isEmpty) {
      state = const PaymentState(
        errorMessage: 'Keranjang tidak boleh kosong',
      );
      return;
    }

    // Get total to validate cash amount
    final total = _ref.read(cartTotalProvider);

    if (cashReceived < total) {
      state = const PaymentState(
        errorMessage: 'Uang yang diterima kurang dari total',
      );
      return;
    }

    // Create transaction using cash factory
    final useCase = getIt<CreateTransaction>();
    final result = await useCase(CreateTransactionParams.cash(
      cartItems: cart,
      cashReceived: cashReceived,
      customerName: customerName,
      notes: notes,
    ));

    result.fold(
      (failure) {
        // Payment failed
        state = PaymentState(errorMessage: failure.message);
      },
      (transaction) {
        // Payment successful - clear cart
        _ref.read(cartProvider.notifier).clear();
        state = PaymentState(completedTransaction: transaction);
      },
    );
  }

  /// Process a debt payment (hutang)
  ///
  /// Requires customer name, creates a transaction with debt status.
  Future<void> processDebtPayment({
    required String customerName,
    String? notes,
  }) async {
    // Set processing state
    state = const PaymentState(isProcessing: true);

    // Get cart items
    final cart = _ref.read(cartProvider);

    if (cart.isEmpty) {
      state = const PaymentState(
        errorMessage: 'Keranjang tidak boleh kosong',
      );
      return;
    }

    // Validate customer name
    if (customerName.trim().isEmpty) {
      state = const PaymentState(
        errorMessage: 'Nama pelanggan harus diisi untuk hutang',
      );
      return;
    }

    // Create transaction using debt factory
    final useCase = getIt<CreateTransaction>();
    final result = await useCase(CreateTransactionParams.debt(
      cartItems: cart,
      customerName: customerName.trim(),
      notes: notes,
    ));

    result.fold(
      (failure) {
        // Payment failed
        state = PaymentState(errorMessage: failure.message);
      },
      (transaction) {
        // Payment successful - clear cart
        _ref.read(cartProvider.notifier).clear();
        state = PaymentState(completedTransaction: transaction);
      },
    );
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use processCashPayment or processDebtPayment instead')
  Future<void> processPayment({
    required double cashReceived,
    String? customerName,
    String? notes,
  }) async {
    return processCashPayment(
      cashReceived: cashReceived,
      customerName: customerName,
      notes: notes,
    );
  }

  /// Reset payment state
  void reset() {
    state = const PaymentState();
  }
}

/// Payment provider
final paymentProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref);
});

/// Provider for the last completed transaction
/// Useful for showing on success screen
final lastCompletedTransactionProvider = Provider<Transaction?>((ref) {
  return ref.watch(paymentProvider).completedTransaction;
});
