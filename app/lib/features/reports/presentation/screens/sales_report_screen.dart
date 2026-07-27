import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/date_range_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/daily_sales_list.dart';
import '../widgets/date_range_selector.dart';
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
        onProfileTap: () {},
      ),
      body: Builder(
        builder: (context) {
          // Calculate bottom padding based on device type to account for bottom nav
          final bottomPadding =
              AppDimensions.spacing16 + context.shellBottomInset;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(salesSummaryProvider);
              ref.invalidate(dailySalesProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppDimensions.spacing16),

                  // Date range selector
                  const DateRangeSelector(),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Summary stats
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: salesSummaryAsync.when(
                      data: (summary) => Column(
                        children: [
                          // Revenue stat
                          SummaryStatCard(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Total Pendapatan',
                            value:
                                CurrencyFormatter.format(summary.totalRevenue),
                            iconColor: AppColors.primary,
                          ),
                          const SizedBox(height: AppDimensions.spacing12),
                          Row(
                            children: [
                              Expanded(
                                child: SummaryStatCard(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Laba',
                                  value: CurrencyFormatter.format(
                                      summary.totalProfit),
                                  iconColor: AppColors.success,
                                  valueColor: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacing12),
                          Row(
                            children: [
                              Expanded(
                                child: SummaryStatCard(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'Transaksi',
                                  value: '${summary.transactionCount}',
                                  iconColor: AppColors.info,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacing12),
                              Expanded(
                                child: SummaryStatCard(
                                  icon: Icons.shopping_bag_rounded,
                                  label: 'Item Terjual',
                                  value: '${summary.itemsSold}',
                                  iconColor: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(
                        height: 200,
                        child: Center(child: ModernLoading()),
                      ),
                      error: (error, _) => ModernErrorState(
                        message: error.toString(),
                        onRetry: () => ref.invalidate(salesSummaryProvider),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Sales chart section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ModernSectionHeader(
                          title: 'Grafik Penjualan',
                          actionLabel: dateRange.label,
                        ),
                        const SizedBox(height: AppDimensions.spacing16),
                        ModernCard.outlined(
                          padding:
                              const EdgeInsets.all(AppDimensions.spacing16),
                          child: dailySalesAsync.when(
                            data: (sales) => SalesBarChart(
                              dailySales: sales,
                              height: 220,
                            ),
                            loading: () => const SizedBox(
                              height: 220,
                              child: Center(child: ModernLoading()),
                            ),
                            error: (error, _) => SizedBox(
                              height: 220,
                              child: ModernErrorState(
                                message: error.toString(),
                                onRetry: () =>
                                    ref.invalidate(dailySalesProvider),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Daily breakdown section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: Column(
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
                            onRetry: () => ref.invalidate(dailySalesProvider),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
