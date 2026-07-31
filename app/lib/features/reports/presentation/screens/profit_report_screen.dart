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
import '../widgets/report_layout.dart';
import '../widgets/top_profitable_products_list.dart';
import '../../../../config/routes/app_router.dart';

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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profitSummaryByDateRangeProvider);
          ref.invalidate(topProfitableProductsProvider);
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

                // The headline figure and the products behind it answer each
                // other, so they share a row once there is width for both.
                ReportSplitRow(
                  splitAt: Breakpoint.expanded,
                  primaryFlex: 1,
                  secondaryFlex: 1,
                  primary: profitAsync.when(
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
                  secondary: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ModernSectionHeader(
                        title: 'Produk Paling Menguntungkan',
                        actionLabel: 'Lihat Semua',
                        onActionTap: () =>
                            context.go(AppRoutes.reportsProducts),
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
                      topProductsAsync.when(
                        data: (products) => TopProfitableProductsList(
                          products: products,
                          onProductTap: (productId) => context
                              .go(AppRoutes.productDetailPath(productId)),
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
                    ],
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
