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
import '../widgets/payment_proof_card.dart';
import '../widgets/transaction_item_tile.dart';
import '../../../../config/routes/app_router.dart';

/// Screen displaying transaction details.
///
/// Serves two routes - `/transactions/:id` and `/debts/:id` - and two
/// presentations: a full screen below the split breakpoint, and the detail pane
/// of whichever list it was opened from above it. It reads [DetailPaneScope] to
/// tell which, rather than being duplicated into a purpose-built panel the way
/// products was: the difference here is a header and a dismissal, not a layout.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.basePath = AppRoutes.transactions,
  });

  final String transactionId;

  /// The list this detail hangs off - `/transactions` from the history,
  /// `/debts` from the hutang list.
  ///
  /// Only used when there is no stack to pop, which is what a deep link or a
  /// refresh leaves you with. `go` synthesises the parent from the URL in every
  /// other case, and the URL already knows which branch you are on.
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync =
        ref.watch(transactionDetailProvider(transactionId));
    final pane = DetailPaneScope.maybeOf(context);

    return Scaffold(
      // Docked, this is not a screen on the window's canvas - it is what the
      // panel is showing, so the panel's own surface has to read through.
      //
      // A Scaffold paints `scaffoldBackgroundColor` by default, which flipped
      // the panel from white to the list's grey the moment a row was selected,
      // and took the divider with it. Transparent here, not
      // `AppColors.surface`: the panel decides what a panel looks like, and one
      // place should own that.
      backgroundColor: pane != null ? Colors.transparent : null,
      // A pane owns no navigation: it has nothing to go back to, and the
      // account menu belongs to the window once. Closing it is what "back"
      // means here, and that is the pane's own affordance.
      appBar: pane != null
          ? ModernAppBar.pane(
              title: 'Detail Transaksi',
              onClose: pane.onClose,
            )
          : ModernAppBar.backWithActions(
              title: 'Detail Transaksi',
              onBack: () {
                // Popping is what returns you to the list you came from -
                // `/debts` or `/transactions`, whichever synthesised this
                // stack. The fallback is for arrivals with no stack at all,
                // like the success screen or a cold deep link.
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(basePath);
                }
              },
            ),
      body: transactionAsync.when(
        loading: () => const Center(child: ModernLoading()),
        error: (error, _) => ModernErrorState.generic(
          message: 'Gagal memuat detail transaksi',
          onRetry: () =>
              ref.invalidate(transactionDetailProvider(transactionId)),
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
    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding = AppDimensions.spacing16 + context.shellBottomInset;

    return ModernContentColumn(
      verticalPadding: EdgeInsets.only(
        top: AppDimensions.spacing16,
        bottom: bottomPadding,
      ),
      child: SingleChildScrollView(
        child: Builder(
          // The tier is read here, inside the content column, and from the
          // *scope* rather than from MediaQuery. Both matter: this screen is
          // also the detail pane of the transactions and debts lists, where it
          // has ~400dp regardless of how wide the window is. Asking the window
          // would put a two-column layout in a phone-width panel.
          builder: (context) => context.isAtLeast(Breakpoint.expanded)
              ? _buildTwoColumn(context, ref, transaction)
              : _buildSingleColumn(context, ref, transaction),
        ),
      ),
    );
  }

  /// Narrow, and in the detail pane: one column of cards.
  Widget _buildSingleColumn(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderCard(transaction),
        const SizedBox(height: AppDimensions.spacing16),
        _buildItemsCard(transaction),
        const SizedBox(height: AppDimensions.spacing16),
        _buildPaymentCard(transaction),
        if (PaymentProofCard.appliesTo(transaction)) ...[
          const SizedBox(height: AppDimensions.spacing16),
          PaymentProofCard(transaction: transaction),
        ],
        const SizedBox(height: AppDimensions.spacing24),
        // Side by side once the column is wider than a phone. In the detail
        // pane this is compact, so they stack there.
        _buildActionButtons(
          context,
          ref,
          transaction,
          stacked: context.isCompact,
        ),
      ],
    );
  }

  /// Wide: the line items on the left, what you owe and what you can do about
  /// it on the right.
  ///
  /// The header spans both columns rather than sitting above one of them - it
  /// names the whole transaction, so it is a title, not a left-column card.
  Widget _buildTwoColumn(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderCard(transaction),
        const SizedBox(height: AppDimensions.spacing16),
        Row(
          // The item list is usually the taller of the two; stretching the
          // totals card to match would leave a card mostly full of nothing.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildItemsCard(transaction)),
            const SizedBox(width: AppDimensions.spacing16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPaymentCard(transaction),
                  if (PaymentProofCard.appliesTo(transaction)) ...[
                    const SizedBox(height: AppDimensions.spacing16),
                    PaymentProofCard(transaction: transaction),
                  ],
                  const SizedBox(height: AppDimensions.spacing16),
                  // Stacked even here: this column is the narrow one, and two
                  // buttons side by side inside it would each be ~150dp.
                  _buildActionButtons(context, ref, transaction, stacked: true),
                ],
              ),
            ),
          ],
        ),
      ],
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
          // Notes (if present)
          //
          // Captured by the payment dialogs since hutang shipped, written to
          // the database, included in the Excel export - and until now shown on
          // no screen in the app. A cashier could type "titip dulu, diambil
          // besok" and never see it again without exporting a spreadsheet.
          if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_outlined,
                  size: AppDimensions.iconSmall,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    transaction.notes!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
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
              value:
                  '- ${CurrencyFormatter.format(transaction.discountAmount)}',
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
    Transaction transaction, {
    required bool stacked,
  }) {
    // Generate receipt text for sharing
    final receiptText =
        ref.watch(receiptTextFromTransactionProvider(transaction));

    final receiptButton = ModernButton.primary(
      fullWidth: true,
      leadingIcon: Icons.receipt_outlined,
      onPressed: () {
        // Always the transaction's receipt, even when this detail was opened
        // from `/debts`: a transaction has one receipt, not one per list it can
        // be reached through, and a `/debts/:id/receipt` duplicate would be a
        // second route to the same print preview. The cost is that backing out
        // of the receipt lands on `/transactions/:id`; the receipt is a leaf
        // you leave, so it is the branch you continue in rather than the one
        // you were sent back to.
        context.go(AppRoutes.receiptPath(transaction.id));
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

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          receiptButton,
          const SizedBox(height: AppDimensions.spacing12),
          shareButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: receiptButton),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(child: shareButton),
      ],
    );
  }
}
