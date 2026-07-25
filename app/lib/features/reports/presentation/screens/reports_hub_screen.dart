import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/date_range_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/date_range_selector.dart';

/// Main reports hub screen with summary cards and navigation to detailed reports
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesSummaryAsync = ref.watch(salesSummaryProvider);
    final dateRange = ref.watch(dateRangeProvider);

    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Laporan',
        onProfileTap: () {},
      ),
      body: Builder(
        builder: (context) {
          // Calculate bottom padding based on device type to account for bottom nav
          final bottomPadding = context.isMobile
              ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
              : AppDimensions.spacing16;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(salesSummaryProvider);
              ref.invalidate(dailySalesProvider);
              ref.invalidate(topProductsByQtyProvider);
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

                  const SizedBox(height: AppDimensions.spacing8),

                  // Current period label
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: Text(
                      dateRange.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing16),

                  // Sales summary card
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: salesSummaryAsync.when(
                      data: (summary) => _buildMainSummaryCard(summary),
                      loading: () => const SizedBox(
                        height: 180,
                        child: Center(child: ModernLoading()),
                      ),
                      error: (error, _) => ModernErrorState(
                        message: error.toString(),
                        onRetry: () => ref.invalidate(salesSummaryProvider),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Report menu cards
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ModernSectionHeader(
                          title: 'Menu Laporan',
                          actionLabel: null,
                        ),
                        const SizedBox(height: AppDimensions.spacing12),
                        _buildReportMenuItem(
                          context: context,
                          icon: Icons.trending_up_rounded,
                          title: 'Laporan Penjualan',
                          subtitle: 'Grafik & detail penjualan harian',
                          color: AppColors.primary,
                          onTap: () => context.push('/reports/sales'),
                        ),
                        const SizedBox(height: AppDimensions.spacing12),
                        _buildReportMenuItem(
                          context: context,
                          icon: Icons.inventory_2_rounded,
                          title: 'Laporan Produk',
                          subtitle:
                              'Produk terlaris berdasarkan qty/pendapatan/laba',
                          color: AppColors.info,
                          onTap: () => context.push('/reports/products'),
                        ),
                        const SizedBox(height: AppDimensions.spacing12),
                        _buildReportMenuItem(
                          context: context,
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Laporan Laba',
                          subtitle: 'Analisis keuntungan per produk',
                          color: AppColors.success,
                          onTap: () => context.push('/reports/profit'),
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

  Widget _buildMainSummaryCard(summary) {
    return ModernGradientCard.success(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Pendapatan',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              CurrencyFormatter.format(summary.totalRevenue),
              style: AppTextStyles.h1.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    label: 'Laba',
                    value: CurrencyFormatter.format(summary.totalProfit),
                    icon: Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _buildMiniStat(
                    label: 'Transaksi',
                    value: '${summary.transactionCount}',
                    icon: Icons.receipt_long,
                  ),
                ),
                Expanded(
                  child: _buildMiniStat(
                    label: 'Item',
                    value: '${summary.itemsSold}',
                    icon: Icons.shopping_bag,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.8),
          size: 20,
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildReportMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ModernCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Icon(
              icon,
              color: color,
              size: AppDimensions.iconLarge,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
