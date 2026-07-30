import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../reports/domain/entities/payment_slice.dart';
import '../../../reports/domain/entities/product_report.dart';
import '../../../reports/domain/entities/sales_trend_point.dart';
import '../../../reports/presentation/widgets/distribution_pie_chart.dart';
import '../../../reports/presentation/widgets/sales_trend_line_chart.dart';
import '../providers/dashboard_analytics_provider.dart';

/// The dashboard's analytics band: how the week is going, under the cards that
/// say how today is going.
///
/// ## Why the dashboard needed a chart at all
///
/// Everything above this band describes a single instant - today's sales, with
/// one delta against yesterday. That answers "is today good?" and nothing else,
/// so a shop could not tell a genuinely bad Tuesday from a Tuesday that is
/// always quiet. A seven-day series is the cheapest thing that answers the
/// question the numbers above provoke.
///
/// ## Reused, not reimplemented
///
/// The charts are the report family's own ([SalesTrendLineChart],
/// [DistributionPieChart]) and the data comes from the same RPCs. That is
/// deliberate: a dashboard chart that computed its own figures would drift out
/// of agreement with the report it links to, and "the dashboard says one thing
/// and Laporan says another" is worse than having no chart.
///
/// ## Each tier adds a block
///
/// Following the rule the rest of this screen already keeps - wider never shows
/// less:
///
/// * **compact** - trend, then top sellers, stacked. The category menu is still
///   on the screen at this tier and there is no room for a third block.
/// * **medium** - all three stacked. Dropping the menu here freed the band a
///   block's worth of room, and the payment mix is what went into it.
/// * **expanded** - trend full width, then top sellers beside the payment mix.
///
/// `large` is *not* handled here. At that tier the screen interleaves these
/// cards with the summary card and the stock alert into two columns, so it
/// composes [DashboardTrendCard], [DashboardTopProductsCard] and
/// [DashboardPaymentMixCard] itself. Putting that arrangement behind this widget
/// would mean handing it the summary card and the alert as parameters, which is
/// the screen's layout leaking into a band that has no business knowing about
/// either.
class DashboardAnalyticsSection extends StatelessWidget {
  const DashboardAnalyticsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tier = context.breakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardAnalyticsHeader(),
        const SizedBox(height: AppDimensions.spacing12),
        if (tier.isExpanded)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The trend takes the full width here rather than a column of a
              // three-up row: a line chart is the one shape on this band that
              // genuinely reads better wide. Measured at 1018dp on a 1100dp
              // window, against 634dp for the widest column of a three-up.
              DashboardTrendCard(),
              SizedBox(height: AppDimensions.spacing20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardCell(child: DashboardTopProductsCard()),
                  SizedBox(width: AppDimensions.spacing20),
                  DashboardCell(child: DashboardPaymentMixCard()),
                ],
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DashboardTrendCard(),
              const SizedBox(height: AppDimensions.spacing20),
              const DashboardTopProductsCard(),
              // Only from `medium`: a phone still carries the category menu
              // below this band, and a third chart above it makes the screen a
              // scroll longer for the tier with the least patience for one.
              if (tier.isMedium) ...[
                const SizedBox(height: AppDimensions.spacing20),
                const DashboardPaymentMixCard(),
              ],
            ],
          ),
      ],
    );
  }
}

/// "Analitik 7 Hari", the range it covers, and a way through to the full report.
///
/// Public because the `large` layout puts it above its analytics column while
/// the screen owns the surrounding two-column Row - see
/// [DashboardAnalyticsSection].
class DashboardAnalyticsHeader extends ConsumerWidget {
  const DashboardAnalyticsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(dashboardAnalyticsWindowProvider);

    return ModernSectionHeader(
      title: 'Analitik $dashboardTrendDays Hari',
      // The cards above are labelled "Hari Ini"; without the range spelled out,
      // a reader has no way to know this band covers something else.
      subtitle: window.label,
      actionLabel: 'Lihat Laporan',
      onActionTap: () => context.go(AppRoutes.reportsAnalytics),
    );
  }
}

/// A column of the band, publishing its own width to the chart inside it.
///
/// The re-scope is not optional. Both charts size their axis labels, their
/// label stride and their donut-versus-legend arrangement from
/// `context.availableWidth`; without a scope at the cell they would read the
/// whole content column and lay out a 1376dp chart inside a 380dp box.
class DashboardCell extends StatelessWidget {
  final int flex;
  final Widget child;

  const DashboardCell({super.key, this.flex = 1, required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: ModernBreakpointScope.fromLayout(child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

/// Revenue and profit per day across the window.
class DashboardTrendCard extends ConsumerWidget {
  /// Height of the plot area. Also the height the loading, error and empty
  /// states occupy, so the card does not resize when the data lands.
  ///
  /// The desktop layout raises this. At `large` the chart is 869dp wide, and at
  /// the default height that is a 4.3:1 plot - wide enough that a real swing in
  /// takings flattens into a nearly straight line. [tallChartHeight] brings it
  /// back to about 3.3:1.
  final double chartHeight;

  const DashboardTrendCard({super.key, this.chartHeight = defaultChartHeight});

  static const double defaultChartHeight = 200;

  /// For the desktop layout, where the chart is much wider.
  static const double tallChartHeight = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(dashboardSalesTrendProvider);

    return _AnalyticsCard(
      icon: Icons.show_chart,
      iconColor: AppColors.primary,
      title: 'Tren Penjualan',
      child: _AsyncBlock<List<SalesTrendPoint>>(
        value: trendAsync,
        height: chartHeight,
        onRetry: () => ref.invalidate(dashboardSalesTrendProvider),
        builder: (points) {
          // A gap-filled series is never empty for a non-empty window, so the
          // "no sales" case is an all-zero series rather than no points. Say so
          // instead of drawing a flat line along the axis and calling it a
          // chart.
          if (points.isEmpty || points.totalRevenue <= 0) {
            return _EmptyBlock(
              height: chartHeight,
              message: 'Belum ada penjualan pada periode ini',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SalesTrendLegend(),
              const SizedBox(height: AppDimensions.spacing12),
              SalesTrendLineChart(points: points, height: chartHeight),
              const SizedBox(height: AppDimensions.spacing12),
              const ModernDivider(),
              const SizedBox(height: AppDimensions.spacing12),
              _TrendTotals(points: points),
            ],
          );
        },
      ),
    );
  }
}

/// Window totals under the trend, so the chart's shape has figures attached.
class _TrendTotals extends StatelessWidget {
  final List<SalesTrendPoint> points;

  const _TrendTotals({required this.points});

  @override
  Widget build(BuildContext context) {
    final revenue = points.totalRevenue;
    final profit = points.totalProfit;
    final margin = revenue == 0 ? 0.0 : (profit / revenue) * 100;

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Pendapatan',
            value: CurrencyFormatter.formatCompact(revenue),
            valueColor: AppColors.textPrimary,
          ),
        ),
        Expanded(
          child: _MiniStat(
            label: 'Laba',
            value: CurrencyFormatter.formatCompact(profit),
            valueColor: profit < 0 ? AppColors.error : AppColors.success,
          ),
        ),
        Expanded(
          child: _MiniStat(
            label: 'Margin',
            value: '${margin.toStringAsFixed(0)}%',
            valueColor: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: AppDimensions.spacing2),
        Text(
          value,
          style: AppTextStyles.priceSmall.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Best sellers of the window, ranked by revenue.
class DashboardTopProductsCard extends ConsumerWidget {
  /// How many rows to render, of the [dashboardTopProductsLimit] fetched.
  ///
  /// Five in a narrow column. The desktop layout passes [maxRowsWide]: there the
  /// card is ~900dp across, and five rows leave two thirds of it empty while the
  /// column beside it runs 200dp longer.
  final int maxRows;

  const DashboardTopProductsCard({super.key, this.maxRows = defaultMaxRows});

  static const int defaultMaxRows = 5;

  /// For the desktop layout, where the card is wide and the column is short.
  static const int maxRowsWide = 8;

  /// Measured height of one row, and the gap between two.
  static const double _rowHeight = 36.5;
  static const double _rowGap = AppDimensions.spacing12;

  /// The height a full list occupies, so the loading and empty states match it
  /// and nothing jumps when the data lands.
  double get _listHeight => maxRows * _rowHeight + (maxRows - 1) * _rowGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(dashboardTopProductsProvider);

    return _AnalyticsCard(
      icon: Icons.emoji_events_outlined,
      iconColor: AppColors.warning,
      title: 'Produk Terlaris',
      onTap: () => context.go(AppRoutes.reportsProducts),
      child: _AsyncBlock<List<ProductReport>>(
        value: productsAsync,
        height: _listHeight,
        onRetry: () => ref.invalidate(dashboardTopProductsProvider),
        builder: (products) {
          if (products.isEmpty) {
            return _EmptyBlock(
              height: _listHeight,
              message: 'Belum ada produk terjual',
            );
          }

          final shown = products.take(maxRows).toList();

          return Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(height: _rowGap),
                _TopProductRow(rank: i + 1, product: shown[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One ranked product.
///
/// Deliberately not the reports' `TopProductTile`. That tile is built for a
/// full-width report list - two stacked lines of text and a right-aligned
/// figure - and in a 380dp column of this band it wraps and then ellipses into
/// uselessness. Same data, denser row.
class _TopProductRow extends StatelessWidget {
  final int rank;
  final ProductReport product;

  const _TopProductRow({required this.rank, required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: Text(
            '$rank',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.productName,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${product.quantitySold} terjual',
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacing8),
        Text(
          CurrencyFormatter.formatCompact(product.totalRevenue),
          style: AppTextStyles.priceSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Turnover split by payment method, with the unpaid share called out.
class DashboardPaymentMixCard extends ConsumerWidget {
  /// Set when this card sits away from [DashboardAnalyticsHeader] - at `large`
  /// it lives in the "today" sidebar, under a summary card and a stock alert
  /// that both describe *today*.
  ///
  /// Without it the card would be a seven-day figure in a column of same-day
  /// ones, which is exactly the period confusion the section header exists to
  /// prevent. Cheaper to label the one card than to mislabel the column.
  final bool showPeriod;

  const DashboardPaymentMixCard({super.key, this.showPeriod = false});

  static const double _chartHeight = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixAsync = ref.watch(dashboardPaymentMixProvider);

    return _AnalyticsCard(
      icon: Icons.pie_chart_outline,
      iconColor: AppColors.info,
      title: 'Metode Bayar',
      subtitle:
          showPeriod ? ref.watch(dashboardAnalyticsWindowProvider).label : null,
      child: _AsyncBlock<List<PaymentSlice>>(
        value: mixAsync,
        height: _chartHeight,
        onRetry: () => ref.invalidate(dashboardPaymentMixProvider),
        builder: (slices) {
          if (slices.isEmpty) {
            return const _EmptyBlock(
              height: _chartHeight,
              message: 'Belum ada transaksi',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DistributionPieChart(
                centerLabel: 'Total',
                height: _chartHeight,
                maxDiameter: 180,
                slices: [
                  for (var i = 0; i < slices.length; i++)
                    PieSliceData(
                      label: slices[i].label,
                      value: slices[i].total,
                      // Same palette ordering the analytics report uses for
                      // this chart, so a slice keeps its colour between the two
                      // screens.
                      color: ColorUtils.paletteAt(i),
                      detail: '${slices[i].transactionCount} transaksi',
                    ),
                ],
              ),
              // The reason this block earns its place on a dashboard: a strong
              // revenue week that is a third hutang is not a strong week, and
              // nothing else here says so.
              if (slices.totalUnpaid > 0) ...[
                const SizedBox(height: AppDimensions.spacing12),
                _UnpaidNote(amount: slices.totalUnpaid),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UnpaidNote extends StatelessWidget {
  final double amount;

  const _UnpaidNote({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: AppDimensions.iconSmall,
          color: AppColors.warning,
        ),
        const SizedBox(width: AppDimensions.spacing8),
        Expanded(
          child: Text(
            'Hutang belum lunas ${CurrencyFormatter.formatCompact(amount)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared shell
// ---------------------------------------------------------------------------

/// The card every block on this band sits in.
///
/// One shell rather than three, so the band reads as a set: same padding, same
/// header shape, same border. The report family gets this from
/// `ReportChartCard`, which is not reusable here because it also caps its own
/// width - correct for a chart standing alone under a section header, wrong for
/// a column of a row that has already been given its width.
class _AnalyticsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  /// Period this card's figures cover. Only set for a card standing away from
  /// [DashboardAnalyticsHeader] - see [DashboardPaymentMixCard.showPeriod].
  final String? subtitle;

  final VoidCallback? onTap;
  final Widget child;

  const _AnalyticsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacing8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: AppDimensions.iconMedium,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          // Inside the padding, so a chart measures the room it actually has
          // rather than the card's outer width - the same ordering
          // `ReportChartCard` documents.
          ModernBreakpointScope.fromLayout(child: child),
        ],
      ),
    );
  }
}

/// Loading, error and data for one block, all at the same height.
///
/// The height matters more than it looks: three of these sit in a row, and a
/// spinner that occupies 40dp while the chart beside it occupies 200dp makes
/// the whole band jump when the slower request lands.
class _AsyncBlock<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final double height;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  const _AsyncBlock({
    required this.value,
    required this.height,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => ModernSkeleton(
        child: ModernSkeletonBox(
          // Explicit, because the card's Column hands its children loose
          // constraints - a null width would shrink-wrap the placeholder to
          // nothing and the loading state would be invisible.
          width: double.infinity,
          height: height,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppDimensions.radiusMedium),
          ),
        ),
      ),
      // `minHeight`, not a fixed height: [ModernErrorState] is a full-screen
      // widget being asked to sit in a 180dp card, and pinning it to that
      // height would overflow the moment its message wrapped to two lines in a
      // narrow column. A floor keeps the band from jumping without capping
      // anything.
      error: (error, _) => ConstrainedBox(
        constraints:
            BoxConstraints(minWidth: double.infinity, minHeight: height),
        child: Center(
          child: ModernErrorState(
            message: 'Gagal memuat data',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}

/// "Nothing to show", occupying the same box the content would have.
class _EmptyBlock extends StatelessWidget {
  final double height;
  final String message;

  const _EmptyBlock({required this.height, required this.message});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // A floor rather than a fixed height, so a message that wraps grows the
      // box instead of overflowing it.
      constraints: BoxConstraints(minWidth: double.infinity, minHeight: height),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing12),
          child: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
