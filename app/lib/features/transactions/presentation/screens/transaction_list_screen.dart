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
import 'transaction_detail_screen.dart';
import '../../../../config/routes/app_router.dart';

/// Screen displaying list of transactions with date filtering.
///
/// ## One screen, one header, the split inside it
///
/// The screen owns the `Scaffold` and the app bar, and the body divides into
/// the list and a docked detail panel - the arrangement `ProductListScreen` and
/// `PosScreen` both use. Wrapping the *whole screen* would put the header
/// inside the left pane, so "Riwayat Transaksi" would stop short of the panel.
class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Riwayat Transaksi',
      ),
      body: MasterDetailScaffold(
        basePath: AppRoutes.transactions,
        selectionParser: AppRoutes.selectedTransactionId,
        // The detail screen itself, not a purpose-built panel: it reads
        // DetailPaneScope and swaps its own chrome. Products needed a panel
        // because its screen's two-column body and scrolling action row both
        // had to change; this one is a single column of cards either way.
        detailBuilder: (context, uri, id) => TransactionDetailScreen(
          key: ValueKey('transaction-$id'),
          transactionId: id,
        ),
        placeholderBuilder: (context) => const _DetailPanePlaceholder(),
        master: const TransactionListPane(),
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
      icon: Icons.receipt_long_outlined,
      title: 'Pilih Transaksi',
      message: 'Pilih transaksi dari daftar untuk melihat detailnya',
    );
  }
}

/// The transaction list itself, filling whichever pane it is given.
///
/// Split out from [TransactionListScreen] so the date chips and the card
/// padding measure themselves against the *pane*, not against the content area
/// the header spans.
class TransactionListPane extends ConsumerStatefulWidget {
  const TransactionListPane({super.key});

  @override
  ConsumerState<TransactionListPane> createState() =>
      _TransactionListPaneState();
}

class _TransactionListPaneState extends ConsumerState<TransactionListPane> {
  final ScrollController _scrollController = ScrollController();

  /// How close to the bottom the list gets before it asks for the next page.
  ///
  /// The same 200dp the POS grid uses. Comfortably less than the height of one
  /// page of cards, so the trigger cannot fire on the frame a page lands and
  /// walk the list forward on its own.
  static const double _loadMoreThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadMoreThreshold) {
      ref.read(transactionListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListProvider);
    final grouped = ref.watch(groupedTransactionsProvider);

    return Column(
      children: [
        // Date filter chips
        const DateFilterChips(),
        const ModernDivider(),
        // Transaction list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(transactionListProvider.notifier).reset(),
            child: _buildBody(context, state, grouped),
          ),
        ),
      ],
    );
  }

  /// The list, or whichever state stands in for it.
  ///
  /// The error and loading branches are guarded on the list being empty: once
  /// there are cards on screen, a failed or in-flight *later* page must not
  /// replace them. Losing ten loaded pages because page eleven timed out is a
  /// worse answer than leaving the list where it was.
  Widget _buildBody(
    BuildContext context,
    TransactionListState state,
    Map<DateTime, List<Transaction>> grouped,
  ) {
    if (state.transactions.isEmpty) {
      if (state.isLoading) {
        return const Center(child: ModernLoading());
      }
      if (state.error != null) {
        return ModernErrorState.generic(
          message: 'Gagal memuat transaksi',
          onRetry: () => ref.read(transactionListProvider.notifier).reset(),
        );
      }
      return _buildEmptyState();
    }

    return _buildTransactionList(context, state, grouped);
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
    TransactionListState state,
    Map<DateTime, List<Transaction>> grouped,
  ) {
    // The pane's padding, not the window's: as a master pane this list is much
    // narrower than the window it sits in, and the deprecated
    // `horizontalPadding` would give it a 32dp desktop inset inside a 600dp
    // column.
    final padding = context.contentPadding;
    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding = AppDimensions.spacing16 + context.shellBottomInset;

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
                    onTap: () =>
                        context.go(AppRoutes.transactionDetailPath(txn.id)),
                  ),
                );
              },
              childCount: transactions.length,
            ),
          ),
        ),
      ];
    }).toList();

    // The next page arriving, or the reason it did not.
    //
    // A failed *later* page reports itself here rather than through the error
    // state, which would have thrown away every card already on screen.
    if (state.isLoadingMore) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacing16),
            child: Center(child: ModernLoading(size: ModernSize.small)),
          ),
        ),
      );
    } else if (state.error != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacing16,
            ),
            child: Center(
              child: ModernButton.text(
                onPressed: () =>
                    ref.read(transactionListProvider.notifier).loadMore(),
                child: const Text('Gagal memuat. Coba lagi'),
              ),
            ),
          ),
        ),
      );
    }

    // Add bottom padding for mobile devices
    slivers.add(
      SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
    );

    return CustomScrollView(
      controller: _scrollController,
      slivers: slivers,
    );
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
