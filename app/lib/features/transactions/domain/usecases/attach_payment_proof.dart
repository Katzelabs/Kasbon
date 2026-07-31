import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/payment_proof/payment_proof_storage.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Attach a photo of the customer's payment screen to an existing sale.
///
/// Two steps that must happen in this order: upload the image, then point the
/// row at it. Doing it the other way round would leave `payment_proof_path`
/// naming an object that does not exist, and the detail screen would show a
/// broken proof for a sale that was actually fine.
///
/// **Deliberately separate from creating the sale.** Compressing and uploading
/// a photo takes seconds on a warung connection and fails on its own schedule;
/// a sale takes one RPC and must not wait. So the money is recorded first and
/// the evidence catches up. If the upload fails, the sale is still a sale - the
/// caller gets a Failure it can turn into a retry, never a rolled-back
/// transaction.
///
/// That ordering is also why this is idempotent-ish rather than idempotent: a
/// retry uploads a second object and repoints the row, leaving the first
/// orphaned in the bucket. Deleting the old one first would risk destroying the
/// only copy if the new upload then failed, which is the worse trade - an
/// orphaned object costs storage, a deleted proof costs the evidence.
class AttachPaymentProof
    implements UseCase<Transaction, AttachPaymentProofParams> {
  final TransactionRepository _repository;
  final PaymentProofStorage _storage;

  AttachPaymentProof(this._repository, this._storage);

  @override
  Future<Either<Failure, Transaction>> call(
    AttachPaymentProofParams params,
  ) async {
    final String objectPath;
    try {
      objectPath = await _storage.upload(params.proof, params.transactionId);
    } on ImageStorageException catch (e) {
      return Left(FileFailure(message: e.message));
    } catch (e) {
      return const Left(
        FileFailure(message: 'Gagal mengunggah bukti pembayaran'),
      );
    }

    // The row is only told about the object once it is actually in the bucket.
    return _repository.updateTransaction(
      params.transactionId,
      paymentProofPath: objectPath,
      // A proof attached later is also a confirmation, for the case where the
      // cashier skipped confirming at the counter and is settling it now. When
      // the sale was already confirmed these rewrite the same values.
      paymentConfirmedAt: params.confirmedAt,
      paymentConfirmedBy: params.confirmedBy.name,
    );
  }
}

/// Parameters for [AttachPaymentProof]
class AttachPaymentProofParams extends Equatable {
  /// The sale the photo belongs to.
  final String transactionId;

  /// The picked image, uncompressed. Compression happens in storage.
  final PickedImage proof;

  /// When the payment was affirmed.
  final DateTime confirmedAt;

  /// What affirmed it. A human, unless something automated grows the ability.
  final PaymentConfirmedBy confirmedBy;

  const AttachPaymentProofParams({
    required this.transactionId,
    required this.proof,
    required this.confirmedAt,
    this.confirmedBy = PaymentConfirmedBy.cashier,
  });

  @override
  List<Object?> get props => [
        transactionId,
        proof.bytes.length,
        confirmedAt,
        confirmedBy,
      ];
}
