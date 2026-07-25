import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/date_range_provider.dart';
import '../providers/profit_report_provider.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/profit_summary_card.dart';
import '../widgets/top_profitable_products_list.dart';

/// Screen displaying profit reports
class ProfitReportScreen extends ConsumerWidget {
  const ProfitReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitAsync = ref.watch(profitSummaryByDateRangeProvider);
    final topProductsAsync = ref.watch(topProfitableProductsProvider);
    final dateRange = ref.watch(dateRangeProvider);

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Laporan Laba',
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
              ref.invalidate(profitSummaryByDateRangeProvider);
              ref.invalidate(topProfitableProductsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppDimensions.spacing16),

                  // Date Range Selector
                  const DateRangeSelector(),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Profit Summary Card with dynamic title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: profitAsync.when(
                      data: (summary) => ProfitSummaryCard(
                        summary: summary,
                        title: 'Total Laba ${dateRange.label}',
                      ),
                      loading: () => const SizedBox(
                        height: 180,
                        child: Center(child: ModernLoading()),
                      ),
                      error: (error, _) => ModernErrorState(
                        message: error.toString(),
                        onRetry: () =>
                            ref.invalidate(profitSummaryByDateRangeProvider),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Section Header with "Lihat Semua" action
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: ModernSectionHeader(
                      title: 'Produk Paling Menguntungkan',
                      actionLabel: 'Lihat Semua',
                      onActionTap: () => context.push('/reports/products'),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing12),

                  // Top Profitable Products List
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: topProductsAsync.when(
                      data: (products) => TopProfitableProductsList(
                        products: products,
                        onProductTap: (productId) =>
                            context.push('/products/$productId'),
                      ),
                      loading: () => const SizedBox(
                        height: 200,
                        child: Center(child: ModernLoading()),
                      ),
                      error: (error, _) => ModernErrorState(
                        message: error.toString(),
                        onRetry: () =>
                            ref.invalidate(topProfitableProductsProvider),
                      ),
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
