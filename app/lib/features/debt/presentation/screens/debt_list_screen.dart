import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/screens/transaction_detail_screen.dart';
import '../providers/debt_provider.dart';
import '../widgets/debt_card.dart';
import '../widgets/debt_summary_card.dart';
import '../../../../config/routes/app_router.dart';

/// Screen for displaying and managing debt transactions.
///
/// The screen owns the `Scaffold` and one header spanning both panes; the split
/// lives in the body, as it does on the products and POS screens.
///
/// A debt's detail is [TransactionDetailScreen] under [AppRoutes.debtDetail] -
/// a route of this feature's own, rather than the tap-through to
/// `/transactions/:id` this list used to do. See the doc on
/// [AppRoutes.debtDetail] for why the branch matters.
class DebtListScreen extends StatelessWidget {
  const DebtListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Hutang',
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: MasterDetailScaffold(
        basePath: AppRoutes.debts,
        selectionParser: AppRoutes.selectedDebtId,
        detailBuilder: (context, uri, id) => TransactionDetailScreen(
          key: ValueKey('debt-$id'),
          transactionId: id,
          basePath: AppRoutes.debts,
        ),
        placeholderBuilder: (context) => const _DetailPanePlaceholder(),
        master: const DebtListPane(),
      ),
    );
  }
}

/// What the detail panel shows before anything is selected.
class _DetailPanePlaceholder extends StatelessWidget {
  const _DetailPanePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ModernEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Pilih Hutang',
      message: 'Pilih hutang dari daftar untuk melihat detail transaksinya',
    );
  }
}

/// The debt list itself, filling whichever pane it is given.
///
/// Split out from [DebtListScreen] so the summary card and the customer
/// sections measure themselves against the *pane*, not against the content area
/// the header spans.
class DebtListPane extends ConsumerWidget {
  const DebtListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(unpaidDebtsProvider);
    final summaryAsync = ref.watch(debtSummaryProvider);
    final debtsByCustomerAsync = ref.watch(debtsByCustomerProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(unpaidDebtsProvider);
      },
      child: debtsAsync.when(
        loading: () => const Center(child: ModernLoading()),
        error: (error, _) => ModernErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(unpaidDebtsProvider),
        ),
        data: (debts) {
          if (debts.isEmpty) {
            return const _EmptyDebtState();
          }

          // Tier padding rather than a flat 16dp: as a master pane this list
          // is narrower than the window, and `contentPadding` reads the pane's
          // own scope, so the inset tracks the column it is actually in.
          final padding = context.contentPadding;

          return CustomScrollView(
            slivers: [
              // Summary card
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: summaryAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (summary) => DebtSummaryCard(summary: summary),
                  ),
                ),
              ),

              // Debts grouped by customer
              debtsByCustomerAsync.when(
                loading: () =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (debtsByCustomer) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entries = debtsByCustomer.entries.toList();
                      final entry = entries[index];
                      final customerName = entry.key;
                      final customerDebts = entry.value;
                      final customerTotal = customerDebts.fold<double>(
                        0,
                        (sum, t) => sum + t.total,
                      );

                      return _CustomerDebtSection(
                        padding: padding,
                        customerName: customerName,
                        customerTotal: customerTotal,
                        debts: customerDebts,
                        // This feature's own detail route, not
                        // `/transactions/:id`. Tapping through to the other
                        // branch is what made back land on the transaction
                        // history and left `/debts` with no detail to dock.
                        onDebtTap: (debt) {
                          context.go(AppRoutes.debtDetailPath(debt.id));
                        },
                        onMarkPaid: (debt) {
                          _showMarkPaidConfirmation(context, ref, debt);
                        },
                      );
                    },
                    childCount: debtsByCustomer.length,
                  ),
                ),
              ),

              // Bottom spacing to clear the shell's bottom nav.
              //
              // Previously unguarded, so it also reserved the bar's height
              // on tablet, where there is no bar - 112px of dead space at
              // the end of the list.
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: AppDimensions.spacing32 + context.shellBottomInset,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMarkPaidConfirmation(
    BuildContext context,
    WidgetRef ref,
    Transaction debt,
  ) async {
    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Tandai Lunas?',
      message:
          'Apakah Anda yakin ingin menandai hutang ${debt.transactionNumber} sebesar ${CurrencyFormatter.format(debt.total)} sebagai lunas?',
      confirmLabel: 'Ya, Lunas',
    );

    if (confirmed == true && context.mounted) {
      // Read before the await: settling the debt drops it out of the list, and
      // with it the selection the URL still points at.
      final wasOpenInPane =
          MasterSelectionScope.selectedIdOf(context) == debt.id;

      final success =
          await ref.read(markDebtPaidProvider.notifier).markAsPaid(debt.id);

      if (context.mounted) {
        if (success) {
          ModernToast.success(context, 'Hutang berhasil ditandai lunas');
          // Otherwise the pane keeps showing a transaction that is no longer a
          // debt, beside a list that no longer contains it.
          if (wasOpenInPane) {
            MasterDetailScaffold.closeDetail(context, AppRoutes.debts);
          }
        } else {
          final error = ref.read(markDebtPaidProvider).error;
          ModernToast.error(context, error ?? 'Gagal menandai lunas');
        }
      }
    }
  }
}

/// Empty state when no debts
class _EmptyDebtState extends StatelessWidget {
  const _EmptyDebtState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: ModernEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Tidak Ada Hutang',
        message: 'Semua transaksi sudah lunas. Bagus!',
      ),
    );
  }
}

/// Section widget for grouping debts by customer
class _CustomerDebtSection extends StatelessWidget {
  const _CustomerDebtSection({
    required this.padding,
    required this.customerName,
    required this.customerTotal,
    required this.debts,
    this.onDebtTap,
    this.onMarkPaid,
  });

  /// Horizontal inset, handed down from the pane so the customer header and
  /// its cards line up with the summary card above them.
  final double padding;

  final String customerName;
  final double customerTotal;
  final List<Transaction> debts;
  final void Function(Transaction)? onDebtTap;
  final void Function(Transaction)? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer header
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: AppDimensions.spacing12,
          ),
          color: AppColors.surfaceVariant,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: AppDimensions.iconMedium,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Text(
                    customerName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(customerTotal),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${debts.length} transaksi',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Debt cards
        Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: debts
                .map(
                  (debt) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spacing12,
                    ),
                    child: DebtCard(
                      transaction: debt,
                      onTap: onDebtTap != null ? () => onDebtTap!(debt) : null,
                      onMarkPaid:
                          onMarkPaid != null ? () => onMarkPaid!(debt) : null,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
