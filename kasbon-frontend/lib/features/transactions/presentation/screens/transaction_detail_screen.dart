import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../../shared/modern/modern.dart';
import '../../../receipt/presentation/providers/receipt_provider.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transactions_provider.dart';
import '../widgets/transaction_item_tile.dart';

/// Screen displaying transaction details
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Detail Transaksi',
        onBack: () {
          // If we can pop (came from transaction list), pop
          // Otherwise navigate to transactions list (came from success screen)
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/transactions');
          }
        },
        onProfileTap: () {},
      ),
      body: transactionAsync.when(
        loading: () => const Center(child: ModernLoading()),
        error: (error, _) => ModernErrorState.generic(
          message: 'Gagal memuat detail transaksi',
          onRetry: () => ref.invalidate(transactionDetailProvider(transactionId)),
        ),
        data: (transaction) => _buildContent(context, ref, transaction),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) {
    final isTablet = context.isTabletOrDesktop;

    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding = context.isMobile
        ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
        : AppDimensions.spacing16;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: isTablet ? AppDimensions.spacing24 : AppDimensions.spacing16,
        right: isTablet ? AppDimensions.spacing24 : AppDimensions.spacing16,
        top: isTablet ? AppDimensions.spacing24 : AppDimensions.spacing16,
        bottom: isTablet ? AppDimensions.spacing24 : bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Transaction header card
          _buildHeaderCard(transaction),
          const SizedBox(height: AppDimensions.spacing16),
          // Items list card
          _buildItemsCard(transaction),
          const SizedBox(height: AppDimensions.spacing16),
          // Payment summary card
          _buildPaymentCard(transaction),
          const SizedBox(height: AppDimensions.spacing24),
          // Action buttons
          _buildActionButtons(context, ref, transaction),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Transaction transaction) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction number
          Text(
            transaction.transactionNumber,
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: AppDimensions.spacing8),
          // Date and time
          Text(
            '${DateFormatter.formatDate(transaction.transactionDate)}, ${DateFormatter.formatTime(transaction.transactionDate)}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          // Status
          Row(
            children: [
              Text(
                'Status: ',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              transaction.isPaid
                  ? const ModernBadge.success(label: 'LUNAS')
                  : const ModernBadge.warning(label: 'HUTANG'),
            ],
          ),
          // Customer name (if present)
          if (transaction.customerName != null &&
              transaction.customerName!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              'Pelanggan: ${transaction.customerName}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(Transaction transaction) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ITEM PEMBELIAN',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          const ModernDivider(),
          ...transaction.items.map(
            (item) => TransactionItemTile(item: item),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Transaction transaction) {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        children: [
          ModernSummaryRow(
            label: 'Subtotal',
            value: CurrencyFormatter.format(transaction.subtotal),
          ),
          if (transaction.discountAmount > 0)
            ModernSummaryRow(
              label: 'Diskon',
              value: '- ${CurrencyFormatter.format(transaction.discountAmount)}',
            ),
          const SizedBox(height: AppDimensions.spacing8),
          const ModernDivider(),
          const SizedBox(height: AppDimensions.spacing8),
          ModernSummaryRow.total(
            label: 'TOTAL',
            value: CurrencyFormatter.format(transaction.total),
          ),
          if (transaction.cashReceived != null &&
              transaction.cashReceived! > 0) ...[
            const SizedBox(height: AppDimensions.spacing16),
            const ModernDivider(),
            const SizedBox(height: AppDimensions.spacing8),
            ModernSummaryRow(
              label: 'Uang Diterima',
              value: CurrencyFormatter.format(transaction.cashReceived!),
            ),
            ModernSummaryRow(
              label: 'Kembalian',
              value: CurrencyFormatter.format(transaction.cashChange ?? 0),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) {
    final isTablet = context.isTabletOrDesktop;

    // Generate receipt text for sharing
    final receiptText = ref.watch(receiptTextFromTransactionProvider(transaction));

    final receiptButton = ModernButton.primary(
      fullWidth: true,
      leadingIcon: Icons.receipt_outlined,
      onPressed: () {
        // Navigate to receipt screen
        context.push('/receipt/${transaction.id}');
      },
      child: const Text('Lihat Struk'),
    );

    final shareButton = ModernButton.outline(
      fullWidth: true,
      leadingIcon: Icons.share_outlined,
      onPressed: () {
        // Show share options
        ShareHelper.showShareOptions(
          context,
          text: receiptText,
          subject: 'Struk ${transaction.transactionNumber}',
        );
      },
      child: const Text('Bagikan Struk'),
    );

    if (isTablet) {
      return Row(
        children: [
          Expanded(child: receiptButton),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(child: shareButton),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        receiptButton,
        const SizedBox(height: AppDimensions.spacing12),
        shareButton,
      ],
    );
  }
}
