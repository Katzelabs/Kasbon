import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/payment_proof/payment_proof_storage.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Swap the photo backing a sale for a better one.
///
/// The common repairs are a blurry shot and a proof filed against the wrong
/// sale. Both are fixed by pointing the row somewhere else, so this is
/// [AttachPaymentProof] plus the cleanup that one deliberately skips.
///
/// **Why this can delete the old object when a retry cannot.** `AttachPaymentProof`
/// leaves the previous object orphaned on a retry, because it cannot tell a
/// retry from a first attempt and deleting the only copy of a proof to make
/// room for an upload that then fails is the expensive direction to be wrong
/// in. Here the ordering removes that risk entirely: the new object is in the
/// bucket and the row already names it before anything is deleted, so the worst
/// case is a file nobody references.
///
/// The reverse failure is handled too. If the row will not accept the new path,
/// the object just uploaded is unreferenced garbage - the row still names the
/// old one, which is still there - so it is cleaned up and the caller gets a
/// Failure describing a sale whose proof never changed.
///
/// Confirmation is not rewritten. A sale with a proof was already confirmed by
/// whoever attached it; re-photographing the customer's screen is a better
/// picture of the same event, not a new one.
class ReplacePaymentProof
    implements UseCase<Transaction, ReplacePaymentProofParams> {
  final TransactionRepository _repository;
  final PaymentProofStorage _storage;

  ReplacePaymentProof(this._repository, this._storage);

  @override
  Future<Either<Failure, Transaction>> call(
    ReplacePaymentProofParams params,
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

    final outcome = await _repository.updateTransaction(
      params.transactionId,
      paymentProofPath: objectPath,
    );

    return outcome.fold(
      (failure) {
        // The row kept the old path, so what was just uploaded is garbage.
        _deleteQuietly(objectPath);
        return Left(failure);
      },
      (transaction) {
        // Now, and only now, is the previous photo unreferenced. The guard on
        // equality matters: if storage handed back the path already on the row,
        // deleting it would erase the live proof.
        if (params.previousObjectPath != null &&
            params.previousObjectPath != objectPath) {
          _deleteQuietly(params.previousObjectPath!);
        }
        return Right(transaction);
      },
    );
  }

  /// Delete an object nobody references, and do not let it fail the operation.
  ///
  /// Not awaited: the row is already correct by this point, and a shop owner
  /// watching a spinner does not care whether a file they cannot see is gone
  /// yet. The try/catch covers a storage client that throws before its first
  /// await; `ignore()` covers the Future failing later. Either way the cost is
  /// an orphan in the bucket.
  void _deleteQuietly(String objectPath) {
    try {
      _storage.delete(objectPath).ignore();
    } catch (_) {
      // Deliberately swallowed - see above.
    }
  }
}

/// Parameters for [ReplacePaymentProof]
class ReplacePaymentProofParams extends Equatable {
  /// The sale whose proof is being swapped.
  final String transactionId;

  /// The new photo, uncompressed. Compression happens in storage.
  final PickedImage proof;

  /// The object the row points at today, deleted once the swap lands.
  ///
  /// Nullable so a caller that somehow lacks it degrades to leaving an orphan
  /// rather than refusing to replace.
  final String? previousObjectPath;

  const ReplacePaymentProofParams({
    required this.transactionId,
    required this.proof,
    this.previousObjectPath,
  });

  @override
  List<Object?> get props => [
        transactionId,
        proof.bytes.length,
        previousObjectPath,
      ];
}
