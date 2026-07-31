import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/usecases/create_transaction.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/mock_data.dart';
import '../../../../../fixtures/mock_repositories.dart';

/// What the use case decides before anything is written.
///
/// The interesting assertions are all about the transaction handed to the
/// repository rather than the one handed back - the repository is stubbed to
/// echo a fixture, so the value under test is the *argument*.
void main() {
  setUpAll(registerMocktailFallbackValues);

  late MockTransactionRepository repository;
  late CreateTransaction useCase;

  setUp(() {
    repository = MockTransactionRepository();
    useCase = CreateTransaction(repository);
    repository.stubGetTodayTransactionCountSuccess(0);
    repository.stubCreateTransactionSuccess(MockData.createTransaction());
  });

  /// The transaction the use case tried to write.
  Transaction captureWritten() {
    return verify(() => repository.createTransaction(captureAny(), any()))
        .captured
        .single as Transaction;
  }

  final cart = [MockData.createCartItem()];

  group('cash', () {
    test('records what was handed over and what comes back', () async {
      await useCase(CreateTransactionParams.cash(
        cartItems: cart,
        cashReceived: 50000,
      ));

      final written = captureWritten();
      expect(written.paymentMethod, PaymentMethod.cash);
      expect(written.cashReceived, 50000);
      expect(written.cashChange, 50000 - written.total);
    });

    test('leaves the payment unconfirmed', () async {
      await useCase(CreateTransactionParams.cash(
        cartItems: cart,
        cashReceived: 50000,
      ));

      // Handing over notes is its own confirmation. Writing 'cashier' here
      // would claim somebody vouched for money nobody was asked about, and
      // make every cash sale indistinguishable from a verified QRIS one.
      final written = captureWritten();
      expect(written.paymentConfirmedAt, isNull);
      expect(written.paymentConfirmedBy, isNull);
    });
  });

  group('QRIS', () {
    test('carries the confirmation the cashier gave', () async {
      final confirmedAt = DateTime(2026, 7, 31, 14, 22);

      await useCase(CreateTransactionParams.qris(
        cartItems: cart,
        confirmedAt: confirmedAt,
      ));

      final written = captureWritten();
      expect(written.paymentMethod, PaymentMethod.qris);
      expect(written.paymentStatus, PaymentStatus.paid);
      expect(written.paymentConfirmedAt, confirmedAt);
      expect(written.paymentConfirmedBy, PaymentConfirmedBy.cashier);
    });

    // The bug this guards: cash fields used to be keyed on "is this debt",
    // so every non-cash method that was not hutang computed
    // `cash_change = 0 - total` and recorded a negative kembalian for money
    // the cashier never took. Debt was the only non-cash method at the time,
    // so it never fired - QRIS would have hit it on the first sale.
    test('records no cash and no change', () async {
      await useCase(CreateTransactionParams.qris(
        cartItems: cart,
        confirmedAt: DateTime(2026, 7, 31),
      ));

      final written = captureWritten();
      expect(written.cashReceived, isNull);
      // Null, specifically - not 0, and emphatically not -total, which is what
      // the old predicate produced.
      expect(written.cashChange, isNull);
    });

    test('takes an optional customer and note', () async {
      await useCase(CreateTransactionParams.qris(
        cartItems: cart,
        confirmedAt: DateTime(2026, 7, 31),
        customerName: 'Bu Sri',
        notes: 'titip dulu',
      ));

      final written = captureWritten();
      expect(written.customerName, 'Bu Sri');
      expect(written.notes, 'titip dulu');
    });
  });

  group('debt', () {
    test('still records no cash, no change and no confirmation', () async {
      await useCase(CreateTransactionParams.debt(
        cartItems: cart,
        customerName: 'Pak Ahmad',
      ));

      final written = captureWritten();
      expect(written.paymentMethod, PaymentMethod.debt);
      expect(written.paymentStatus, PaymentStatus.debt);
      expect(written.cashReceived, isNull);
      expect(written.cashChange, isNull);
      expect(written.paymentConfirmedAt, isNull);
    });
  });

  group('refusals', () {
    test('will not write an empty cart', () async {
      final result = await useCase(CreateTransactionParams.qris(
        cartItems: const [],
        confirmedAt: DateTime(2026, 7, 31),
      ));

      expect(result, isA<Left<Failure, Transaction>>());
      verifyNever(() => repository.createTransaction(any(), any()));
    });
  });
}
