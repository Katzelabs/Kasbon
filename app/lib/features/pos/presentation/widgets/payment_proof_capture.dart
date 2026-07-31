import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/image_picking/image_source_picker.dart';
import '../../../../shared/modern/modern.dart';

/// Captures the photo that backs a QRIS sale, and hands back the bytes.
///
/// **Holds the image; never uploads it.** This is the difference from
/// [ProductImagePicker], which saves to storage the moment a photo is picked.
/// It cannot work that way here: a proof is stored at
/// `<user_id>/<transaction_id>/...` and the transaction does not exist yet -
/// the cashier is still standing in the dialog deciding whether to confirm.
///
/// So the bytes live in the parent dialog's state until the sale commits, and
/// the upload happens afterwards against a real transaction id. A cancelled
/// dialog therefore leaves nothing behind in the bucket, which is the same
/// property `ProductImagePicker` had to be rewritten to get.
///
/// Two sources because cashiers do this two ways: photograph the customer's
/// phone across the counter, or accept a screenshot the customer already sent.
/// The camera is absent where there is none - on web `supportsCameraCapture` is
/// false and the gallery entry becomes a file picker.
class PaymentProofCapture extends StatefulWidget {
  const PaymentProofCapture({
    super.key,
    required this.proof,
    required this.onProofChanged,
  });

  /// The currently held image, or null when none has been taken.
  final PickedImage? proof;

  /// Called with the new image, or null when it is cleared.
  final ValueChanged<PickedImage?> onProofChanged;

  @override
  State<PaymentProofCapture> createState() => _PaymentProofCaptureState();
}

class _PaymentProofCaptureState extends State<PaymentProofCapture> {
  bool _isBusy = false;

  Future<void> _showSourceSheet() async {
    setState(() => _isBusy = true);

    final result = await pickImageFromSource(
      context,
      title: 'Bukti Pembayaran',
      cameraLabel: 'Foto Layar Pelanggan',
      galleryLabel: 'Pilih dari Galeri',
      allowClear: widget.proof != null,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    switch (result) {
      case ImagePicked(:final image):
        widget.onProofChanged(image);
      case ImagePickCleared():
        widget.onProofChanged(null);
      case ImagePickCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProof = widget.proof != null;

    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      onTap: _isBusy ? null : _showSourceSheet,
      child: Row(
        children: [
          _Thumbnail(proof: widget.proof, isBusy: _isBusy),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasProof ? 'Bukti terlampir' : 'Foto Bukti (opsional)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  hasProof
                      ? 'Ketuk untuk ganti atau hapus'
                      : 'Potret layar berhasil di HP pelanggan',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasProof)
            const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: AppDimensions.iconLarge,
            ),
        ],
      ),
    );
  }
}

/// The picked photo, or a placeholder standing in for it.
///
/// Renders from memory - these bytes have never been to a server, so there is
/// no path to resolve and nothing to sign.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.proof, required this.isBusy});

  final PickedImage? proof;
  final bool isBusy;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: switch ((isBusy, proof)) {
        (true, _) => const Center(child: ModernLoading.small()),
        (false, final PickedImage p) => Image.memory(
            p.bytes,
            fit: BoxFit.cover,
            width: _size,
            height: _size,
          ),
        _ => const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.textTertiary,
          ),
      },
    );
  }
}
