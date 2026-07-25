import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/product_report.dart';
import '../providers/report_provider.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/product_report_filter_card.dart';
import '../../../../config/routes/app_router.dart';

/// Screen displaying product sales report in a data table format
class ProductReportScreen extends ConsumerStatefulWidget {
  const ProductReportScreen({super.key});

  @override
  ConsumerState<ProductReportScreen> createState() =>
      _ProductReportScreenState();
}

class _ProductReportScreenState extends ConsumerState<ProductReportScreen> {
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(filteredProductReportProvider);

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Laporan Produk',
        onBack: () => context.pop(),
        onProfileTap: () {},
      ),
      body: Column(
        children: [
          const SizedBox(height: AppDimensions.spacing16),

          // Date range selector
          const DateRangeSelector(),

          const SizedBox(height: AppDimensions.spacing12),

          // Sort dropdown
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
            child: ProductReportFilterCard(),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Product list
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: ModernLoading()),
              error: (error, _) => Center(
                child: ModernErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(filteredProductReportProvider),
                ),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: ModernEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Tidak Ada Data',
                      message: 'Belum ada penjualan pada periode ini',
                    ),
                  );
                }
                return _buildProductList(context, products);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<ProductReport> products) {
    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding = context.isMobile
        ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
        : AppDimensions.spacing16;

    return ListView.separated(
      padding: EdgeInsets.only(
        left: AppDimensions.spacing16,
        right: AppDimensions.spacing16,
        top: AppDimensions.spacing8,
        bottom: bottomPadding,
      ),
      itemCount: products.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacing8),
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, product, index + 1);
      },
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductReport product,
    int rank,
  ) {
    return ModernCard.outlined(
      onTap: () => context.go(AppRoutes.productDetailPath(product.productId)),
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: rank, name, margin
          Row(
            children: [
              // Rank badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _getRankColor(rank).withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: _getRankColor(rank),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              // Product name
              Expanded(
                child: Text(
                  product.productName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              // Margin badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getMarginColor(product.profitMargin)
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Text(
                  'Margin ${product.profitMargin.toStringAsFixed(0)}%',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _getMarginColor(product.profitMargin),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          // Stats row
          Row(
            children: [
              // Qty sold
              Expanded(
                child: _buildStatItem(
                  label: 'Terjual',
                  value: '${product.quantitySold} pcs',
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
              // Revenue
              Expanded(
                child: _buildStatItem(
                  label: 'Pendapatan',
                  value: CurrencyFormatter.formatCompact(product.totalRevenue),
                  icon: Icons.payments_outlined,
                ),
              ),
              // Profit
              Expanded(
                child: _buildStatItem(
                  label: 'Laba',
                  value: CurrencyFormatter.formatCompact(product.totalProfit),
                  icon: Icons.trending_up,
                  valueColor: product.totalProfit >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) => AppColors.rankColor(rank);

  Color _getMarginColor(double margin) {
    if (margin >= 30) return AppColors.success;
    if (margin >= 15) return AppColors.warning;
    if (margin >= 0) return AppColors.info;
    return AppColors.error;
  }
}
