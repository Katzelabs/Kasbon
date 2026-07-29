import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/receipt_provider.dart';
import '../widgets/receipt_preview_widget.dart';

/// Full-screen receipt view with sharing options
///
/// Displays the receipt preview and provides buttons to:
/// - Copy to clipboard
/// - Share via WhatsApp
/// - Share via system share sheet
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({
    super.key,
    required this.transactionId,
  });

  /// The transaction ID to generate receipt for
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(receiptProvider(transactionId));

    return Scaffold(
      appBar: ModernAppBar.back(
        title: 'Struk Pembelian',
        onBack: () => context.pop(),
      ),
      body: receiptAsync.when(
        loading: () => const Center(child: ModernLoading()),
        error: (error, _) => ModernErrorState.generic(
          message: 'Gagal memuat struk',
          onRetry: () => ref.invalidate(receiptProvider(transactionId)),
        ),
        data: (receiptData) => _buildContent(context, ref, receiptData),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ReceiptData receiptData,
  ) {
    // A receipt is a fixed 42 monospace characters wide - it does not get
    // wider, only more centred - so the column replaces the hand-rolled 400dp
    // clamp that used to sit around the preview.
    //
    // The action bar is deliberately *outside* it. The bar is chrome docked to
    // the bottom of the screen, and its background and top shadow have to run
    // edge to edge to read as one; only the buttons inside it are clamped, so
    // they still line up with the receipt above.
    return Column(
      children: [
        Expanded(
          child: ModernContentColumn.form(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing16,
              ),
              child: ReceiptPreviewWidget(
                receiptText: receiptData.receiptText,
              ),
            ),
          ),
        ),
        _buildActionButtons(context, receiptData),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ReceiptData receiptData) {
    final copyButton = ModernButton.outline(
      size: ModernSize.medium,
      fullWidth: true,
      leadingIcon: Icons.copy_outlined,
      onPressed: () => ShareHelper.copyToClipboard(
        context,
        receiptData.receiptText,
        successMessage: 'Struk berhasil disalin',
      ),
      child: const Text('Salin ke Clipboard'),
    );

    final whatsAppButton = ModernButton.outline(
      size: ModernSize.medium,
      fullWidth: true,
      leadingIcon: Icons.chat_outlined,
      onPressed: () => ShareHelper.shareViaWhatsApp(
        context,
        receiptData.receiptText,
      ),
      child: const Text('Kirim via WhatsApp'),
    );

    final shareButton = ModernButton.primary(
      size: ModernSize.medium,
      fullWidth: true,
      leadingIcon: Icons.share_outlined,
      onPressed: () => ShareHelper.shareText(
        receiptData.receiptText,
        subject: 'Struk ${receiptData.transaction.transactionNumber}',
      ),
      child: const Text('Bagikan'),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ModernContentColumn.form(
          verticalPadding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacing16,
          ),
          child: Builder(
            // Inside the column, so the tier reported here is the clamped
            // width - which is what decides whether three buttons fit in a
            // row, rather than how wide the window happens to be.
            builder: (context) => context.isAtLeast(Breakpoint.medium)
                ? Row(
                    children: [
                      Expanded(child: copyButton),
                      const SizedBox(width: AppDimensions.spacing8),
                      Expanded(child: whatsAppButton),
                      const SizedBox(width: AppDimensions.spacing8),
                      Expanded(child: shareButton),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      copyButton,
                      const SizedBox(height: AppDimensions.spacing8),
                      whatsAppButton,
                      const SizedBox(height: AppDimensions.spacing8),
                      shareButton,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
