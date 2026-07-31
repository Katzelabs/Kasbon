import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/daily_sales.dart';
import '../providers/date_range_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/daily_sales_list.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/report_layout.dart';
import '../widgets/sales_bar_chart.dart';
import '../widgets/summary_stat_card.dart';

/// Screen displaying detailed sales report with chart and daily breakdown
class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesSummaryAsync = ref.watch(salesSummaryProvider);
    final dailySalesAsync = ref.watch(dailySalesProvider);
    final dateRange = ref.watch(dateRangeProvider);

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Laporan Penjualan',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesSummaryProvider);
          ref.invalidate(dailySalesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: AppDimensions.spacing16,
            bottom: AppDimensions.spacing32 + context.shellBottomInset,
          ),
          child: ModernContentColumn(
            width: ContentWidth.wide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DateRangeSelector(padding: EdgeInsets.zero),

                const SizedBox(height: AppDimensions.spacing24),

                salesSummaryAsync.when(
                  data: (summary) => _StatGrid(summary: summary),
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: ModernLoading()),
                  ),
                  error: (error, _) => ModernErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(salesSummaryProvider),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // The chart and the numbers behind it are one thought, so on a
                // desktop window they sit side by side instead of making the
                // reader scroll between them.
                ReportSplitRow(
                  primaryFlex: 2,
                  secondaryFlex: 1,
                  primary: _ChartSection(
                    dailySalesAsync: dailySalesAsync,
                    rangeLabel: dateRange.label,
                    onRetry: () => ref.invalidate(dailySalesProvider),
                  ),
                  secondary: _DailyBreakdownSection(
                    dailySalesAsync: dailySalesAsync,
                    onRetry: () => ref.invalidate(dailySalesProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four headline figures.
///
/// Two grids rather than one: the currency figures need roughly 260dp before
/// `Rp 1.250.000` stops wrapping under an icon, while a transaction count is
/// legible at half that. One grid sized for the widest tile would stack all
/// four on a phone; one sized for the narrowest would wrap the money.
class _StatGrid extends StatelessWidget {
  final dynamic summary;

  const _StatGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReportTileGrid(
          minTileWidth: 260,
          maxColumns: 2,
          children: [
            SummaryStatCard(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Total Pendapatan',
              value: CurrencyFormatter.format(summary.totalRevenue),
              iconColor: AppColors.primary,
            ),
            SummaryStatCard(
              icon: Icons.trending_up_rounded,
              label: 'Laba',
              value: CurrencyFormatter.format(summary.totalProfit),
              iconColor: AppColors.success,
              valueColor: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing12),
        ReportTileGrid(
          minTileWidth: 160,
          maxColumns: 2,
          children: [
            SummaryStatCard(
              icon: Icons.receipt_long_rounded,
              label: 'Transaksi',
              value: '${summary.transactionCount}',
              iconColor: AppColors.info,
            ),
            SummaryStatCard(
              icon: Icons.shopping_bag_rounded,
              label: 'Item Terjual',
              value: '${summary.itemsSold}',
              iconColor: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  final AsyncValue<List<DailySales>> dailySalesAsync;
  final String rangeLabel;
  final VoidCallback onRetry;

  const _ChartSection({
    required this.dailySalesAsync,
    required this.rangeLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // A taller plot is the point of a wider pane: the same series in a 220dp
    // strip across 900dp reads as a horizon, not a chart.
    final chartHeight = context.responsive<double>(
      compact: 220,
      expanded: 280,
      large: 320,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(
          title: 'Grafik Penjualan',
          actionLabel: rangeLabel,
        ),
        const SizedBox(height: AppDimensions.spacing16),
        ReportChartCard(
          maxWidth: ReportChartWidths.dailyBar,
          child: dailySalesAsync.when(
            data: (sales) => SalesBarChart(
              dailySales: sales,
              height: chartHeight,
            ),
            loading: () => SizedBox(
              height: chartHeight,
              child: const Center(child: ModernLoading()),
            ),
            error: (error, _) => SizedBox(
              height: chartHeight,
              child: ModernErrorState(
                message: error.toString(),
                onRetry: onRetry,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyBreakdownSection extends StatelessWidget {
  final AsyncValue<List<DailySales>> dailySalesAsync;
  final VoidCallback onRetry;

  const _DailyBreakdownSection({
    required this.dailySalesAsync,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModernSectionHeader(
          title: 'Rincian Harian',
          actionLabel: null,
        ),
        const SizedBox(height: AppDimensions.spacing12),
        dailySalesAsync.when(
          data: (sales) => DailySalesList(
            dailySales: sales,
            showAll: true,
          ),
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: ModernLoading()),
          ),
          error: (error, _) => ModernErrorState(
            message: error.toString(),
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}
