import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/errors/exceptions.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/core/services/payment_proof/payment_proof_storage.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/usecases/attach_payment_proof.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/mock_data.dart';
import '../../../../../fixtures/mock_repositories.dart';

/// Ordering, mostly.
///
/// Upload then point the row at it - never the other way round. A row naming an
/// object that was never written renders as a broken proof for a sale that was
/// perfectly fine, which is worse than a sale with no proof at all.
void main() {
  setUpAll(registerMocktailFallbackValues);

  late MockTransactionRepository repository;
  late MockPaymentProofStorage storage;
  late AttachPaymentProof useCase;

  final proof = PickedImage(bytes: Uint8List.fromList([1, 2, 3]));
  final confirmedAt = DateTime(2026, 7, 31, 14, 22);

  setUp(() {
    repository = MockTransactionRepository();
    storage = MockPaymentProofStorage();
    useCase = AttachPaymentProof(repository, storage);
    repository.stubUpdateTransactionSuccess(MockData.createTransaction());
  });

  AttachPaymentProofParams params() => AttachPaymentProofParams(
        transactionId: 'trx-1',
        proof: proof,
        confirmedAt: confirmedAt,
      );

  test('uploads, then points the row at what was uploaded', () async {
    when(() => storage.upload(any(), any()))
        .thenAnswer((_) async => 'uid/trx-1/123.jpg');

    final result = await useCase(params());

    expect(result, isA<Right<Failure, Transaction>>());

    verifyInOrder([
      () => storage.upload(proof, 'trx-1'),
      () => repository.updateTransaction(
            'trx-1',
            paymentProofPath: 'uid/trx-1/123.jpg',
            paymentConfirmedAt: confirmedAt,
            paymentConfirmedBy: 'cashier',
          ),
    ]);
  });

  test('leaves the row alone when the upload fails', () async {
    when(() => storage.upload(any(), any())).thenThrow(
      const ImageStorageException(
        message: 'Gagal mengunggah bukti pembayaran',
        code: 'PROOF_UPLOAD_FAILED',
      ),
    );

    final result = await useCase(params());

    expect(result, isA<Left<Failure, Transaction>>());
    // The sale itself is untouched and still valid - only the evidence is
    // missing, and the detail screen will offer to try again.
    verifyNever(() => repository.updateTransaction(
          any(),
          paymentProofPath: any(named: 'paymentProofPath'),
          paymentConfirmedAt: any(named: 'paymentConfirmedAt'),
          paymentConfirmedBy: any(named: 'paymentConfirmedBy'),
        ));
  });

  test('surfaces the storage message rather than a generic one', () async {
    when(() => storage.upload(any(), any())).thenThrow(
      const ImageStorageException(
        message: 'Ukuran file melebihi batas',
        code: 'PROOF_UPLOAD_FAILED',
      ),
    );

    final result = await useCase(params());

    expect(
      result.fold((f) => f.message, (_) => null),
      'Ukuran file melebihi batas',
    );
  });

  test('turns an unexpected throw into a failure, not a crash', () async {
    when(() => storage.upload(any(), any())).thenThrow(StateError('boom'));

    final result = await useCase(params());

    expect(result, isA<Left<Failure, Transaction>>());
  });
}
