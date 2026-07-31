import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/services/payment_proof/payment_proof_storage.dart';

/// A viewable URL for the proof stored at an object path.
///
/// Minted on demand rather than stored, because `payment-proofs` is a private
/// bucket: there is no public URL to keep in the row, and a signed one expires.
/// That is the right trade here - a proof is opened when somebody goes back to
/// settle an argument about one sale, so the link only has to outlive the
/// screen that asked for it.
///
/// autoDispose so closing the detail screen drops the URL. The next open signs
/// a fresh one, which is cheaper than reasoning about whether a cached link is
/// still alive.
final paymentProofUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, objectPath) {
  return getIt<PaymentProofStorage>().signedUrlFor(objectPath);
});
