import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../../transactions/domain/entities/transaction.dart';

/// Confirmation modal shown the moment a sale completes.
///
/// This replaced a full `/pos/success/:id` screen. The screen re-fetched the
/// transaction it had just been handed the id of, and pushing a route meant the
/// cashier left the POS grid and had to navigate back for the next sale. The
/// modal takes the [Transaction] the payment already returned - no second
/// round-trip - and dismisses straight back onto the grid, which is where the
/// next customer is waiting.
///
/// Deliberately short: the transaction number, what was paid, and the change to
/// hand over. Anything more detailed belongs on the receipt, one tap away.
class TransactionSuccessDialog extends StatelessWidget {
  const TransactionSuccessDialog({
    super.key,
    required this.transaction,
  });

  /// The transaction that was just created.
  final Transaction transaction;

  /// Show the modal for a completed [transaction].
  ///
  /// Pass a context that outlives the payment dialog - that dialog pops itself
  /// before this opens, so its own context is on its way out. The root
  /// navigator's context is the reliable one:
  ///
  /// ```dart
  /// final navigator = Navigator.of(context, rootNavigator: true);
  /// Navigator.pop(context, true);
  /// await TransactionSuccessDialog.show(navigator.context, transaction);
  /// ```
  static Future<void> show(
    BuildContext context,
    Transaction transaction,
  ) {
    return ModernDialog.show<void>(
      context,
      child: TransactionSuccessDialog(transaction: transaction),
    );
  }

  bool get _isDebt => transaction.paymentStatus == PaymentStatus.debt;

  @override
  Widget build(BuildContext context) {
    final accent = _isDebt ? AppColors.warning : AppColors.success;

    return Padding(
      // Tighter at the top than the sides: the close button carries its own
      // touch-target padding, so a full 24 above it would float the whole
      // dialog down. Left and right stay equal - the content below is centred.
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing24,
        AppDimensions.spacing12,
        AppDimensions.spacing24,
        AppDimensions.spacing24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ModernIconButton(
              icon: Icons.close,
              tooltip: 'Tutup',
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color:
                    _isDebt ? AppColors.warningLight : AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDebt ? Icons.schedule : Icons.check_circle,
                size: AppDimensions.iconXLarge,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            _isDebt ? 'Hutang Tercatat' : 'Pembayaran Berhasil!',
            textAlign: TextAlign.center,
            style: AppTextStyles.h3.copyWith(color: accent),
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            transaction.transactionNumber,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing20),

          // The numbers the cashier acts on: what was owed, and - for cash -
          // what to hand back.
          ModernCard.filled(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModernSummaryRow.total(
                  label: 'Total',
                  value: CurrencyFormatter.format(transaction.total),
                  valueColor: accent,
                ),
                if (_isDebt) ...[
                  const ModernDivider(),
                  ModernSummaryRow(
                    label: 'Pelanggan',
                    value: transaction.customerName ?? '-',
                  ),
                ] else ...[
                  const ModernDivider(),
                  ModernSummaryRow(
                    label: 'Uang Diterima',
                    value: CurrencyFormatter.format(
                      transaction.cashReceived ?? 0,
                    ),
                  ),
                  ModernSummaryRow(
                    label: 'Kembalian',
                    value: CurrencyFormatter.format(
                      transaction.cashChange ?? 0,
                    ),
                    valueStyle: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const ModernDivider(),
                ModernSummaryRow(
                  label: 'Jumlah Item',
                  value: '${transaction.items.length} item',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacing24),

          // OverflowBar, not Row: "Lihat Struk" and "Transaksi Baru" side by
          // side do not fit a 420dp dialog on a small phone.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: AppDimensions.spacing12,
            overflowSpacing: AppDimensions.spacing8,
            children: [
              ModernButton.outline(
                onPressed: () {
                  // Resolve the router before popping - afterwards this
                  // context's element is defunct and the lookup would throw.
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.go(AppRoutes.transactionDetailPath(transaction.id));
                },
                child: const Text('Lihat Struk'),
              ),
              ModernButton.primary(
                onPressed: () => Navigator.pop(context),
                child: const Text('Transaksi Baru'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
