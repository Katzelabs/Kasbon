import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transactions_provider.dart';
import '../widgets/date_filter_chips.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_date_header.dart';
import '../../../../config/routes/app_router.dart';

/// Screen displaying list of transactions with date filtering
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedTransactionsProvider);

    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Riwayat Transaksi',
        onProfileTap: () {},
      ),
      body: Column(
        children: [
          // Date filter chips
          const DateFilterChips(),
          const ModernDivider(),
          // Transaction list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(transactionsProvider);
              },
              child: groupedAsync.when(
                loading: () => const Center(child: ModernLoading()),
                error: (error, _) => ModernErrorState.generic(
                  message: 'Gagal memuat transaksi',
                  onRetry: () => ref.invalidate(transactionsProvider),
                ),
                data: (grouped) {
                  if (grouped.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildTransactionList(context, grouped);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const ModernEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'Belum Ada Transaksi',
      message: 'Transaksi akan muncul di sini setelah Anda melakukan penjualan',
    );
  }

  Widget _buildTransactionList(
    BuildContext context,
    Map<DateTime, List<Transaction>> grouped,
  ) {
    final padding = context.horizontalPadding;
    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding =
        AppDimensions.spacing16 + context.shellBottomInset;

    final slivers = grouped.entries.expand((entry) {
      final date = entry.key;
      final transactions = entry.value;

      return [
        // Date header (sticky)
        SliverPersistentHeader(
          pinned: true,
          delegate: _DateHeaderDelegate(date: date),
        ),
        // Transaction cards
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: AppDimensions.spacing8,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final txn = transactions[index];
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacing12,
                  ),
                  child: TransactionCard(
                    transaction: txn,
                    onTap: () => context.go(AppRoutes.transactionDetailPath(txn.id)),
                  ),
                );
              },
              childCount: transactions.length,
            ),
          ),
        ),
      ];
    }).toList();

    // Add bottom padding for mobile devices
    slivers.add(
      SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
    );

    return CustomScrollView(slivers: slivers);
  }
}

/// Delegate for sticky date headers
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime date;

  _DateHeaderDelegate({required this.date});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return TransactionDateHeader(date: date);
  }

  @override
  double get maxExtent => TransactionDateHeader.headerHeight;

  @override
  double get minExtent => TransactionDateHeader.headerHeight;

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return date != oldDelegate.date;
  }
}
