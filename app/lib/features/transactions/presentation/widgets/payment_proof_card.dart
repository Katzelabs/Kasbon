import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/cached_remote_image.dart';
import '../../../../shared/image_picking/image_source_picker.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/attach_payment_proof.dart';
import '../../domain/usecases/remove_payment_proof.dart';
import '../../domain/usecases/replace_payment_proof.dart';
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
///
/// An attached proof can be swapped or deleted, from an overflow menu rather
/// than from buttons beside the photo. Looking at the proof is what nearly
/// every visit here is for; editing it is the rare repair, and two controls
/// competing with the thumbnail would invert that.
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
  bool _isBusy = false;

  Future<void> _attach() async {
    final result = await pickImageFromSource(
      context,
      title: 'Lampirkan Bukti',
      cameraLabel: 'Foto Layar Pelanggan',
      galleryLabel: 'Pilih dari Galeri',
    );

    if (result is! ImagePicked || !mounted) return;

    // Unlike the POS, this uploads straight away: the transaction already
    // exists, so there is a real id to file the object under, and nobody is
    // waiting at a counter.
    await _run(
      () => getIt<AttachPaymentProof>()(AttachPaymentProofParams(
        transactionId: widget.transaction.id,
        proof: result.image,
        confirmedAt: widget.transaction.paymentConfirmedAt ?? DateTime.now(),
      )),
      successMessage: 'Bukti pembayaran tersimpan',
    );
  }

  /// The overflow menu on an attached proof: re-shoot it, or delete it.
  ///
  /// The same sheet the POS dialog uses, so replacing a proof after the fact
  /// looks like replacing one before the sale committed.
  Future<void> _showProofActions() async {
    final result = await pickImageFromSource(
      context,
      title: 'Bukti Pembayaran',
      cameraLabel: 'Foto Ulang',
      galleryLabel: 'Pilih dari Galeri',
      clearLabel: 'Hapus Bukti',
      allowClear: true,
    );

    if (!mounted) return;

    switch (result) {
      case ImagePicked(:final image):
        await _replace(image);
      case ImagePickCleared():
        await _remove();
      case ImagePickCancelled():
        break;
    }
  }

  Future<void> _replace(PickedImage image) async {
    await _run(
      () => getIt<ReplacePaymentProof>()(ReplacePaymentProofParams(
        transactionId: widget.transaction.id,
        proof: image,
        previousObjectPath: widget.transaction.paymentProofPath,
      )),
      successMessage: 'Bukti pembayaran diganti',
    );
  }

  Future<void> _remove() async {
    final path = widget.transaction.paymentProofPath;
    if (path == null) return;

    // Deleting a proof cannot be undone and the photo is often the only record
    // of a QRIS payment this app holds, so it asks first. Replacing does not -
    // that ends with a proof still attached.
    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Hapus Bukti?',
      message: 'Foto bukti pembayaran akan dihapus permanen. '
          'Transaksi dan status pembayarannya tidak berubah.',
      confirmLabel: 'Hapus',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => getIt<RemovePaymentProof>()(RemovePaymentProofParams(
        transactionId: widget.transaction.id,
        objectPath: path,
      )),
      successMessage: 'Bukti pembayaran dihapus',
    );
  }

  /// Runs one of the three actions with the busy flag, the toast and the
  /// re-read that all of them need.
  Future<void> _run(
    Future<Either<Failure, Transaction>> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _isBusy = true);

    final outcome = await action();

    if (!mounted) return;
    setState(() => _isBusy = false);

    outcome.fold(
      (failure) => ModernToast.error(context, failure.message),
      (_) {
        ModernToast.success(context, successMessage);
        // Re-read the row so the card follows what the proof now is - a photo,
        // a different photo, or the empty state again.
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'BUKTI PEMBAYARAN',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Only where there is something to act on. On the empty state the
              // sole action is already a button below, and a menu offering
              // "replace" and "delete" for a photo that does not exist would be
              // two dead entries.
              if (transaction.hasPaymentProof)
                ModernIconButton.standard(
                  icon: Icons.more_horiz,
                  size: ModernSize.small,
                  tooltip: 'Ganti atau hapus bukti',
                  onPressed: _isBusy ? null : _showProofActions,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          const ModernDivider(),
          const SizedBox(height: AppDimensions.spacing12),
          if (transaction.hasPaymentProof)
            _AttachedProof(transaction: transaction, isBusy: _isBusy)
          else
            _MissingProof(
              isAttaching: _isBusy,
              onAttach: _isBusy ? null : _attach,
            ),
        ],
      ),
    );
  }
}

/// A stored proof: who confirmed it, when, and the photo itself.
class _AttachedProof extends ConsumerWidget {
  const _AttachedProof({required this.transaction, this.isBusy = false});

  final Transaction transaction;

  /// A swap or a delete is in flight.
  ///
  /// The photo is replaced by a spinner rather than dimmed in place, because
  /// the thumbnail on screen is about to stop being the truth and leaving it
  /// visible would suggest the tap did nothing.
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isBusy) {
      return const _ProofFrame(child: Center(child: ModernLoading()));
    }

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
          loading: () =>
              const _ProofFrame(child: Center(child: ModernLoading())),
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
          data: (url) => _ProofThumbnail(
            url: url,
            objectPath: transaction.paymentProofPath!,
          ),
        ),
      ],
    );
  }
}

/// The photo, tappable into a full-size viewer.
class _ProofThumbnail extends StatelessWidget {
  const _ProofThumbnail({required this.url, required this.objectPath});

  /// A signed URL, valid for minutes and different on every view.
  final String url;

  /// The object's path in the bucket - stable, and therefore what the cache
  /// keys on. Keying on [url] instead would miss every single time: a fresh
  /// signature per view means the cache would fill and never be read.
  final String objectPath;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullSize(context, url, objectPath),
      child: _ProofFrame(
        child: CachedRemoteImage(
          url: url,
          cacheKey: objectPath,
          fit: BoxFit.cover,
          errorWidget: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  static void _showFullSize(
    BuildContext context,
    String url,
    String objectPath,
  ) {
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
              // Same key as the thumbnail, so opening the viewer reads the
              // bytes the card already fetched instead of paying for them
              // again.
              child: CachedRemoteImage(
                url: url,
                cacheKey: objectPath,
                fit: BoxFit.contain,
                showProgress: true,
                errorWidget: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
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
