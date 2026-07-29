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
      body: ModernContentColumn(
        width: ContentWidth.wide,
        verticalPadding: const EdgeInsets.only(top: AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FilterToolbar(),

            const SizedBox(height: AppDimensions.spacing16),

            // Product list
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: ModernLoading()),
                error: (error, _) => Center(
                  child: ModernErrorState(
                    message: error.toString(),
                    onRetry: () =>
                        ref.invalidate(filteredProductReportProvider),
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

                  // A table needs room for six columns before it beats the
                  // cards; below expanded it would be a horizontal scroll
                  // hiding half the figures.
                  return context.isAtLeast(Breakpoint.expanded)
                      ? _buildProductTable(context, products)
                      : _buildProductList(context, products);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<ProductReport> products) {
    return ListView.separated(
      padding: EdgeInsets.only(
        top: AppDimensions.spacing8,
        bottom: AppDimensions.spacing16 + context.shellBottomInset,
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

  /// The expanded-and-up form: one row per product, all six figures visible.
  Widget _buildProductTable(
    BuildContext context,
    List<ProductReport> products,
  ) {
    // Rank is the item's position in the sorted result, which a column builder
    // is not told. Indexing by id once beats an indexOf per cell.
    final ranks = {
      for (var i = 0; i < products.length; i++) products[i].productId: i + 1,
    };

    return ModernDataTable<ProductReport>(
      items: products,
      idGetter: (product) => product.productId,
      showCheckboxColumn: false,
      onRowTap: (product) =>
          context.go(AppRoutes.productDetailPath(product.productId)),
      narrowBuilder: (context, product, _) => _buildProductCard(
        context,
        product,
        ranks[product.productId] ?? 0,
      ),
      columns: [
        ModernTableColumn<ProductReport>(
          id: 'rank',
          header: const Text('#'),
          width: 52,
          alignment: Alignment.center,
          cellBuilder: (product) => Text(
            '${ranks[product.productId]}',
            style: AppTextStyles.labelMedium.copyWith(
              color: _getRankColor(ranks[product.productId] ?? 0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ModernTableColumn<ProductReport>(
          id: 'name',
          header: const Text('Produk'),
          flex: 3,
          minWidth: 160,
          cellBuilder: (product) => Text(
            product.productName,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ModernTableColumn<ProductReport>(
          id: 'qty',
          header: const Text('Terjual'),
          width: 96,
          alignment: Alignment.centerRight,
          cellBuilder: (product) => Text('${product.quantitySold} pcs'),
        ),
        ModernTableColumn<ProductReport>(
          id: 'revenue',
          header: const Text('Pendapatan'),
          width: 132,
          alignment: Alignment.centerRight,
          cellBuilder: (product) => Text(
            CurrencyFormatter.format(product.totalRevenue),
          ),
        ),
        ModernTableColumn<ProductReport>(
          id: 'profit',
          header: const Text('Laba'),
          width: 132,
          alignment: Alignment.centerRight,
          cellBuilder: (product) => Text(
            CurrencyFormatter.format(product.totalProfit),
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: product.totalProfit >= 0
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ),
        ModernTableColumn<ProductReport>(
          id: 'margin',
          header: const Text('Margin'),
          width: 104,
          alignment: Alignment.centerRight,
          cellBuilder: (product) => Text(
            '${product.profitMargin.toStringAsFixed(0)}%',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: _getMarginColor(product.profitMargin),
            ),
          ),
        ),
      ],
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
            // Three of these share a card, so on a 375dp phone each gets about
            // 100dp - less than "Pendapatan" and its icon need. Ellipsise
            // rather than overflow.
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

/// Date chips and the sort control.
///
/// One line at medium and up, where there is room for both; stacked on a phone
/// rather than squeezing the sort dropdown into whatever the chips leave.
class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar();

  @override
  Widget build(BuildContext context) {
    if (!context.isAtLeast(Breakpoint.medium)) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateRangeSelector(padding: EdgeInsets.zero),
          SizedBox(height: AppDimensions.spacing12),
          ProductReportFilterCard(),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(child: DateRangeSelector(padding: EdgeInsets.zero)),
        const SizedBox(width: AppDimensions.spacing16),
        // Bounded rather than flexible: a second flex child would split the
        // row evenly with the chips, and the sort control does not want half
        // a desktop window. The cap also gives the card's own Flexible
        // something finite to work against.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: const ProductReportFilterCard(),
        ),
      ],
    );
  }
}
