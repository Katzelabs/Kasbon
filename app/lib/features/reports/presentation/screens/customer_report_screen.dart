import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/customer_analytics.dart';
import '../providers/analytics_provider.dart';
import '../widgets/customer_analytics_tile.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/report_layout.dart';

/// Top customers and their lifetime value.
class CustomerReportScreen extends ConsumerWidget {
  const CustomerReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(topCustomersProvider);

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Laporan Pelanggan',
        onProfileTap: () {},
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(topCustomersProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: AppDimensions.spacing16,
            bottom: AppDimensions.spacing32 + context.shellBottomInset,
          ),
          child: ModernContentColumn(
            // The rest of the report family clamps at wide; this screen was
            // the odd one out at the 1080dp default.
            width: ContentWidth.wide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DateRangeSelector(padding: EdgeInsets.zero),
                const SizedBox(height: AppDimensions.spacing24),
                customersAsync.when(
                  data: (customers) => _buildContent(context, ref, customers),
                  loading: () => const SizedBox(
                    height: 240,
                    child: Center(child: ModernLoading()),
                  ),
                  error: (error, _) => ModernErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(topCustomersProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<CustomerAnalytics> customers,
  ) {
    if (customers.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Belum Ada Data Pelanggan',
        // Explains the cause rather than just the symptom: the POS only
        // records a customer when a name is entered at checkout.
        message: 'Nama pelanggan hanya tercatat jika diisi saat transaksi. '
            'Isi nama pelanggan di kasir untuk melihat laporan ini.',
      );
    }

    final debtors = customers.withOutstandingDebt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportTileGrid(
          minTileWidth: 160,
          maxColumns: 3,
          children: [
            _SummaryTile(
              label: 'Total Belanja',
              value: CurrencyFormatter.format(customers.totalSpent),
              color: AppColors.primary,
            ),
            _SummaryTile(
              label: 'Pelanggan',
              value: '${customers.length}',
              color: AppColors.info,
            ),
            if (debtors.isNotEmpty)
              _SummaryTile(
                label: 'Total Hutang',
                value: CurrencyFormatter.formatCompact(
                  customers.totalOutstandingDebt,
                ),
                color: AppColors.warning,
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(
          title: 'Pelanggan Teratas',
          subtitle: 'Berdasarkan total belanja pada periode ini',
        ),
        const SizedBox(height: AppDimensions.spacing12),
        // Two columns of tiles once there is room. Capped at two: a customer
        // row carries a name, a spend, a recency line and sometimes a debt
        // badge, and three columns start truncating the names.
        ReportTileGrid(
          minTileWidth: 360,
          maxColumns: 2,
          children: [
            for (var i = 0; i < customers.length; i++)
              CustomerAnalyticsTile(
                customer: customers[i],
                rank: i + 1,
              ),
          ],
        ),
        _LoadMore(shown: customers.length),
      ],
    );
  }
}

/// Extends the customer list a page at a time.
///
/// A full page back means there is probably more; a short one means the list
/// ended, so the footer settles into a plain count.
class _LoadMore extends ConsumerWidget {
  final int shown;

  const _LoadMore({required this.shown});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(customerReportLimitProvider);

    return ReportLoadMoreFooter(
      shown: shown,
      itemLabel: 'pelanggan',
      onLoadMore: shown < limit
          ? null
          : () => ref.read(customerReportLimitProvider.notifier).state =
              limit + customerReportPageSize,
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.filled(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
