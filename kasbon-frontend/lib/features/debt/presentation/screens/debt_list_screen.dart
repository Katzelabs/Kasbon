import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../providers/debt_provider.dart';
import '../widgets/debt_card.dart';
import '../widgets/debt_summary_card.dart';

/// Screen for displaying and managing debt transactions
class DebtListScreen extends ConsumerWidget {
  const DebtListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(unpaidDebtsProvider);
    final summaryAsync = ref.watch(debtSummaryProvider);
    final debtsByCustomerAsync = ref.watch(debtsByCustomerProvider);

    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Hutang',
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: RefreshIndicator(
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

            return CustomScrollView(
              slivers: [
                // Summary card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
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
                          customerName: customerName,
                          customerTotal: customerTotal,
                          debts: customerDebts,
                          onDebtTap: (debt) {
                            // Navigate to transaction detail
                            context.push('/transactions/${debt.id}');
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

                // Bottom spacing for mobile bottom nav
                const SliverPadding(
                  padding: EdgeInsets.only(
                    bottom:
                        AppDimensions.bottomNavHeight + AppDimensions.spacing32,
                  ),
                ),
              ],
            );
          },
        ),
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
      final success =
          await ref.read(markDebtPaidProvider.notifier).markAsPaid(debt.id);

      if (context.mounted) {
        if (success) {
          ModernToast.success(context, 'Hutang berhasil ditandai lunas');
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
    required this.customerName,
    required this.customerTotal,
    required this.debts,
    this.onDebtTap,
    this.onMarkPaid,
  });

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
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
          padding: const EdgeInsets.all(AppDimensions.spacing16),
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
