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
    final isTablet = context.isTabletOrDesktop;

    return Column(
      children: [
        // Scrollable receipt preview
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              isTablet ? AppDimensions.spacing24 : AppDimensions.spacing16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ReceiptPreviewWidget(
                  receiptText: receiptData.receiptText,
                ),
              ),
            ),
          ),
        ),
        // Action buttons
        _buildActionButtons(context, receiptData),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ReceiptData receiptData) {
    final isTablet = context.isTabletOrDesktop;

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

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
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
        child: isTablet
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
    );
  }
}
