import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/errors/exceptions.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/core/services/payment_proof/payment_proof_storage.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/usecases/replace_payment_proof.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/mock_data.dart';
import '../../../../../fixtures/mock_repositories.dart';

/// Which object is safe to delete, and when.
///
/// Every test here is about that one question. A proof is often the only record
/// of a QRIS payment the app holds, so the rule is that nothing is deleted
/// until the row demonstrably points somewhere else - and if the swap fails
/// halfway, what gets cleaned up is the copy nobody references.
void main() {
  setUpAll(registerMocktailFallbackValues);

  late MockTransactionRepository repository;
  late MockPaymentProofStorage storage;
  late ReplacePaymentProof useCase;

  final proof = PickedImage(bytes: Uint8List.fromList([4, 5, 6]));
  const oldPath = 'uid/trx-1/111.jpg';
  const newPath = 'uid/trx-1/222.jpg';

  setUp(() {
    repository = MockTransactionRepository();
    storage = MockPaymentProofStorage();
    useCase = ReplacePaymentProof(repository, storage);
    repository.stubUpdateTransactionSuccess(MockData.createTransaction());
    when(() => storage.upload(any(), any())).thenAnswer((_) async => newPath);
    when(() => storage.delete(any())).thenAnswer((_) async {});
  });

  ReplacePaymentProofParams params({String? previous = oldPath}) =>
      ReplacePaymentProofParams(
        transactionId: 'trx-1',
        proof: proof,
        previousObjectPath: previous,
      );

  test('uploads, repoints the row, then deletes the old object', () async {
    final result = await useCase(params());

    expect(result, isA<Right<Failure, Transaction>>());

    verifyInOrder([
      () => storage.upload(proof, 'trx-1'),
      () => repository.updateTransaction('trx-1', paymentProofPath: newPath),
      () => storage.delete(oldPath),
    ]);
  });

  // The confirmation is a record that a human saw the customer's screen. A
  // better photograph of that same moment does not re-confirm it, and rewriting
  // the timestamp would move a sale's confirmation to whenever someone happened
  // to tidy up the photo.
  test('leaves the confirmation alone', () async {
    await useCase(params());

    verify(() =>
            repository.updateTransaction('trx-1', paymentProofPath: newPath))
        .called(1);
    verifyNever(() => repository.updateTransaction(
          any(),
          paymentConfirmedAt: any(named: 'paymentConfirmedAt'),
          paymentConfirmedBy: any(named: 'paymentConfirmedBy'),
        ));
  });

  test('keeps the old proof when the upload fails', () async {
    when(() => storage.upload(any(), any())).thenThrow(
      const ImageStorageException(
        message: 'Gagal mengunggah bukti pembayaran',
        code: 'PROOF_UPLOAD_FAILED',
      ),
    );

    final result = await useCase(params());

    expect(result, isA<Left<Failure, Transaction>>());
    verifyNever(() => storage.delete(any()));
    verifyNever(() => repository.updateTransaction(any(),
        paymentProofPath: any(named: 'paymentProofPath')));
  });

  // The row still names the old object, so the old object is still the proof.
  // Deleting it here would destroy a good photo over a failed write.
  test('deletes the new object, not the old, when the row rejects it',
      () async {
    repository.stubUpdateTransactionFailure(
      const DatabaseFailure(message: 'Gagal memperbarui transaksi'),
    );

    final result = await useCase(params());

    expect(result, isA<Left<Failure, Transaction>>());
    verify(() => storage.delete(newPath)).called(1);
    verifyNever(() => storage.delete(oldPath));
  });

  test('deletes nothing when there was no previous object', () async {
    final result = await useCase(params(previous: null));

    expect(result, isA<Right<Failure, Transaction>>());
    verifyNever(() => storage.delete(any()));
  });

  // Storage could hand back the path already on the row - a fixed filename, a
  // clock that did not move. Deleting it would erase the photo the row now
  // points at, which is the one failure this whole ordering exists to prevent.
  test('does not delete when the new object landed on the old path', () async {
    when(() => storage.upload(any(), any())).thenAnswer((_) async => oldPath);

    final result = await useCase(params());

    expect(result, isA<Right<Failure, Transaction>>());
    verifyNever(() => storage.delete(any()));
  });

  // The row is correct by the time this runs, so a bucket that refuses the
  // delete costs an unreferenced file and nothing else.
  test('still succeeds when deleting the old object fails', () async {
    when(() => storage.delete(any())).thenThrow(
      const ImageStorageException(message: 'boom', code: 'DELETE_FAILED'),
    );

    final result = await useCase(params());

    expect(result, isA<Right<Failure, Transaction>>());
  });
}
