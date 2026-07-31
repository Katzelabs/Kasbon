import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/services/payment_proof/payment_proof_storage.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/attach_payment_proof.dart';
import '../../../transactions/domain/usecases/create_transaction.dart';
import 'cart_provider.dart';

/// Selected payment method for the current transaction
enum SelectedPaymentMethod {
  cash,
  qris,
  debt;

  String get label {
    switch (this) {
      case SelectedPaymentMethod.cash:
        return 'Tunai';
      case SelectedPaymentMethod.qris:
        return 'QRIS';
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

  /// Record a QRIS payment taken on a printed sticker.
  ///
  /// There is no amount to check. On QRIS statis the customer scans the sticker
  /// and types the total into their own wallet app, so nothing here ever sees
  /// what they typed - this app is recording that a cashier looked at a success
  /// screen and said yes, which is the only verification a sticker affords.
  ///
  /// [proof] is optional and, when present, deliberately **not awaited**.
  ///
  /// The sale is already recorded by the time the upload starts. Compressing
  /// and sending a photo takes seconds on a warung connection, and making the
  /// cashier watch a spinner for money that has already changed hands - with a
  /// queue at the counter - is the one thing this flow must not do. So the
  /// upload is launched and abandoned.
  ///
  /// Abandoned, not ignored: if it fails the row simply has no
  /// `payment_proof_path`, which the transaction detail screen renders as
  /// "bukti belum dilampirkan" with a button to attach one. The recovery path
  /// is a place the cashier can go back to, rather than a toast that would pop
  /// over whatever sale they had already started.
  ///
  /// Nothing in the continuation touches [state]. This provider is autoDispose
  /// and the dialog that owns it closes immediately after a sale, so by the
  /// time the upload finishes this notifier is usually gone - and a StateNotifier
  /// throws if you write to it after disposal.
  Future<void> processQrisPayment({
    PickedImage? proof,
    String? customerName,
    String? notes,
  }) async {
    state = const PaymentState(isProcessing: true);

    final cart = _ref.read(cartProvider);

    if (cart.isEmpty) {
      state = const PaymentState(
        errorMessage: 'Keranjang tidak boleh kosong',
      );
      return;
    }

    final confirmedAt = DateTime.now();

    final useCase = getIt<CreateTransaction>();
    final result = await useCase(CreateTransactionParams.qris(
      cartItems: cart,
      confirmedAt: confirmedAt,
      customerName: customerName,
      notes: notes,
    ));

    result.fold(
      (failure) {
        state = PaymentState(errorMessage: failure.message);
      },
      (transaction) {
        if (proof != null) {
          unawaited(_attachProofInBackground(
            transactionId: transaction.id,
            proof: proof,
            confirmedAt: confirmedAt,
          ));
        }

        _ref.read(cartProvider.notifier).clear();
        state = PaymentState(completedTransaction: transaction);
      },
    );
  }

  /// Uploads a proof for an already-committed sale.
  ///
  /// Resolved through GetIt rather than this notifier's [Ref] on purpose: it
  /// has to keep working after the notifier is disposed, and reading a
  /// disposed Ref throws.
  Future<void> _attachProofInBackground({
    required String transactionId,
    required PickedImage proof,
    required DateTime confirmedAt,
  }) async {
    try {
      await getIt<AttachPaymentProof>()(AttachPaymentProofParams(
        transactionId: transactionId,
        proof: proof,
        confirmedAt: confirmedAt,
      ));
    } catch (_) {
      // Swallowed by design. The sale is safe, the proof is not, and the
      // transaction detail screen is where that gets noticed and fixed.
    }
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
