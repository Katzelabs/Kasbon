import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/payment_proof/payment_proof_storage.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Detach a photo from a sale and delete it.
///
/// **Why a POS allows this at all.** Financial records here are append-only -
/// nothing edits an amount or a line item - so permitting a deletion needs a
/// reason. It is that a proof filed against the wrong sale is worse than no
/// proof: a missing photo is honestly absent, a misattributed one actively
/// misleads whoever is settling a dispute, and without this the wrong sale
/// carries someone else's payment screen forever.
///
/// The evidence being deleted is also not the record of the money. With a
/// static QRIS sticker the authoritative trail is the merchant statement; this
/// photograph is a reconciliation aid that helps match a line there to a line
/// here. Removing it destroys a convenience copy, not the sale.
///
/// **Row first, object second.** The inverse of [AttachPaymentProof], and for
/// the same reason: a row must never name an object that is not there. Deleting
/// the file first and then failing to clear the column would leave the detail
/// screen showing a broken proof for a sale that is otherwise fine. This way a
/// failed delete leaves an unreferenced file, which nobody ever sees.
///
/// Confirmation survives - see `TransactionRepository.clearPaymentProof`.
class RemovePaymentProof
    implements UseCase<Transaction, RemovePaymentProofParams> {
  final TransactionRepository _repository;
  final PaymentProofStorage _storage;

  RemovePaymentProof(this._repository, this._storage);

  @override
  Future<Either<Failure, Transaction>> call(
    RemovePaymentProofParams params,
  ) async {
    final outcome = await _repository.clearPaymentProof(params.transactionId);

    return outcome.map((transaction) {
      // Nothing references the object now. Not awaited, and failures dropped:
      // the row is already correct, so the cheap way to fail here is an orphan
      // in the bucket. The try/catch covers a storage client that throws before
      // its first await; `ignore()` covers the Future failing later. Without
      // both, a bucket refusing the delete would report the removal as failed
      // when the column is already clear.
      try {
        _storage.delete(params.objectPath).ignore();
      } catch (_) {
        // Deliberately swallowed - see above.
      }
      return transaction;
    });
  }
}

/// Parameters for [RemovePaymentProof]
class RemovePaymentProofParams extends Equatable {
  /// The sale losing its proof.
  final String transactionId;

  /// The object to delete once the row no longer names it.
  final String objectPath;

  const RemovePaymentProofParams({
    required this.transactionId,
    required this.objectPath,
  });

  @override
  List<Object?> get props => [transactionId, objectPath];
}
