import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/image_picking/image_source_picker.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/attach_payment_proof.dart';
import '../providers/payment_proof_provider.dart';
import '../providers/transactions_provider.dart';

/// The photo backing a QRIS sale - or the offer to add one.
///
/// Shown for any sale that either has a proof or could have one. A cash sale
/// has neither: notes changing hands is its own evidence, and a card inviting
/// the shop owner to photograph something would be noise on every row.
///
/// The empty state is the important half. A proof can be missing for two
/// ordinary reasons - the cashier skipped it with a queue waiting, or the
/// background upload failed on a flat connection - and neither is an error
/// worth interrupting anyone over at the time. This is where it gets noticed,
/// which is the whole reason the upload is allowed to fail silently.
class PaymentProofCard extends ConsumerStatefulWidget {
  const PaymentProofCard({super.key, required this.transaction});

  final Transaction transaction;

  /// Whether this sale warrants the card at all.
  static bool appliesTo(Transaction transaction) =>
      transaction.hasPaymentProof ||
      transaction.paymentMethod == PaymentMethod.qris;

  @override
  ConsumerState<PaymentProofCard> createState() => _PaymentProofCardState();
}

class _PaymentProofCardState extends ConsumerState<PaymentProofCard> {
  bool _isAttaching = false;

  Future<void> _attach() async {
    final result = await pickImageFromSource(
      context,
      title: 'Lampirkan Bukti',
      cameraLabel: 'Foto Layar Pelanggan',
      galleryLabel: 'Pilih dari Galeri',
    );

    if (result is! ImagePicked || !mounted) return;

    setState(() => _isAttaching = true);

    // Unlike the POS, this uploads straight away: the transaction already
    // exists, so there is a real id to file the object under, and nobody is
    // waiting at a counter.
    final outcome = await getIt<AttachPaymentProof>()(AttachPaymentProofParams(
      transactionId: widget.transaction.id,
      proof: result.image,
      confirmedAt: widget.transaction.paymentConfirmedAt ?? DateTime.now(),
    ));

    if (!mounted) return;
    setState(() => _isAttaching = false);

    outcome.fold(
      (failure) => ModernToast.error(context, failure.message),
      (_) {
        ModernToast.success(context, 'Bukti pembayaran tersimpan');
        // Re-read the row so the card swaps from the empty state to the photo.
        ref.invalidate(transactionDetailProvider(widget.transaction.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;

    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUKTI PEMBAYARAN',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          const ModernDivider(),
          const SizedBox(height: AppDimensions.spacing12),
          if (transaction.hasPaymentProof)
            _AttachedProof(transaction: transaction)
          else
            _MissingProof(
              isAttaching: _isAttaching,
              onAttach: _isAttaching ? null : _attach,
            ),
        ],
      ),
    );
  }
}

/// A stored proof: who confirmed it, when, and the photo itself.
class _AttachedProof extends ConsumerWidget {
  const _AttachedProof({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync =
        ref.watch(paymentProofUrlProvider(transaction.paymentProofPath!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (transaction.paymentConfirmedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: AppDimensions.iconSmall,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'Dikonfirmasi '
                    '${transaction.paymentConfirmedBy?.label.toLowerCase() ?? ''} '
                    '${DateFormatter.formatTime(transaction.paymentConfirmedAt!)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        urlAsync.when(
          loading: () => const _ProofFrame(child: Center(child: ModernLoading())),
          // A signed URL can fail for reasons that have nothing to do with the
          // photo - no network, an expired session. Saying "the proof is gone"
          // would be a stronger claim than we can make, so this offers a retry.
          error: (_, __) => _ProofFrame(
            child: Center(
              child: ModernButton.text(
                size: ModernSize.small,
                onPressed: () => ref.invalidate(
                  paymentProofUrlProvider(transaction.paymentProofPath!),
                ),
                child: const Text('Gagal memuat - coba lagi'),
              ),
            ),
          ),
          data: (url) => _ProofThumbnail(url: url),
        ),
      ],
    );
  }
}

/// The photo, tappable into a full-size viewer.
class _ProofThumbnail extends StatelessWidget {
  const _ProofThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullSize(context, url),
      child: _ProofFrame(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  static void _showFullSize(BuildContext context, String url) {
    // A proof is read, not admired: the amount is often small in frame and the
    // photo was taken across a counter, so panning and zooming is the point.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Bukti Pembayaran'),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed-height box the proof renders into.
///
/// A payment screenshot is tall and portrait, and letting it size itself would
/// push the rest of the detail screen off the bottom.
class _ProofFrame extends StatelessWidget {
  const _ProofFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// No photo on file, and the way to fix that.
class _MissingProof extends StatelessWidget {
  const _MissingProof({required this.isAttaching, required this.onAttach});

  final bool isAttaching;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Text(
                'Bukti belum dilampirkan',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing12),
        ModernButton.outline(
          size: ModernSize.small,
          onPressed: onAttach,
          isLoading: isAttaching,
          child: const Text('Lampirkan Bukti'),
        ),
      ],
    );
  }
}
