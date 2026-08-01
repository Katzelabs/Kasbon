import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/errors/exceptions.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/usecases/remove_payment_proof.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/mock_data.dart';
import '../../../../../fixtures/mock_repositories.dart';

/// Ordering again, inverted.
///
/// Attaching writes the object first so the row never names a file that is not
/// there. Removing writes the row first for exactly the same reason: a column
/// still pointing at a deleted object renders as a broken proof on a sale that
/// is otherwise fine.
void main() {
  setUpAll(registerMocktailFallbackValues);

  late MockTransactionRepository repository;
  late MockPaymentProofStorage storage;
  late RemovePaymentProof useCase;

  const path = 'uid/trx-1/111.jpg';

  setUp(() {
    repository = MockTransactionRepository();
    storage = MockPaymentProofStorage();
    useCase = RemovePaymentProof(repository, storage);
    repository.stubClearPaymentProofSuccess(MockData.createTransaction());
    when(() => storage.delete(any())).thenAnswer((_) async {});
  });

  const params = RemovePaymentProofParams(
    transactionId: 'trx-1',
    objectPath: path,
  );

  test('clears the row, then deletes the object', () async {
    final result = await useCase(params);

    expect(result, isA<Right<Failure, Transaction>>());

    verifyInOrder([
      () => repository.clearPaymentProof('trx-1'),
      () => storage.delete(path),
    ]);
  });

  test('keeps the object when the row will not clear', () async {
    repository.stubClearPaymentProofFailure(
      const DatabaseFailure(message: 'Gagal menghapus bukti pembayaran'),
    );

    final result = await useCase(params);

    expect(result, isA<Left<Failure, Transaction>>());
    // The row still names it, so it is still the proof.
    verifyNever(() => storage.delete(any()));
  });

  // By this point the column is already NULL - the proof is detached whatever
  // the bucket says. Reporting a failure would tell the shop owner to try
  // again at something that already happened.
  test('succeeds even when the object cannot be deleted', () async {
    when(() => storage.delete(any())).thenThrow(
      const ImageStorageException(message: 'boom', code: 'DELETE_FAILED'),
    );

    final result = await useCase(params);

    expect(result, isA<Right<Failure, Transaction>>());
  });

  test('survives a delete that fails asynchronously', () async {
    when(() => storage.delete(any())).thenAnswer(
      (_) async => throw const ImageStorageException(
        message: 'boom',
        code: 'DELETE_FAILED',
      ),
    );

    final result = await useCase(params);

    expect(result, isA<Right<Failure, Transaction>>());
  });
}
