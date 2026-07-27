import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/payment_slice.dart';
import '../../domain/entities/sales_trend_point.dart';
import '../providers/analytics_provider.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/day_of_week_bar_chart.dart';
import '../widgets/distribution_pie_chart.dart';
import '../widgets/export_bottom_sheet.dart';
import '../widgets/hourly_sales_heatmap.dart';
import '../widgets/peak_hours_card.dart';
import '../widgets/period_comparison_card.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/sales_trend_line_chart.dart';

/// Advanced analytics: trends, distributions, and time-of-day patterns.
class AnalyticsReportScreen extends ConsumerWidget {
  const AnalyticsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = context.isMobile
        ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
        : AppDimensions.spacing16;

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Analitik Lanjutan',
        onProfileTap: () {},
        additionalActions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Ekspor Laporan',
            onPressed: () => ExportBottomSheet.show(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateAnalytics(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppDimensions.spacing16),
              DateRangeSelector(),
              SizedBox(height: AppDimensions.spacing16),
              _Section(child: ReportFilterBar()),
              SizedBox(height: AppDimensions.spacing24),
              _TrendSection(),
              SizedBox(height: AppDimensions.spacing24),
              _ComparisonSection(),
              SizedBox(height: AppDimensions.spacing24),
              _CategorySection(),
              SizedBox(height: AppDimensions.spacing24),
              _PaymentSection(),
              SizedBox(height: AppDimensions.spacing24),
              _HeatmapSection(),
              SizedBox(height: AppDimensions.spacing24),
              _DayOfWeekSection(),
              SizedBox(height: AppDimensions.spacing32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard horizontal inset for a block of report content.
class _Section extends StatelessWidget {
  final Widget child;

  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: child,
    );
  }
}

/// Renders an async report block with consistent loading and error states.
class _AsyncBlock<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final double loadingHeight;

  const _AsyncBlock({
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loadingHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => SizedBox(
        height: loadingHeight,
        child: const Center(child: ModernLoading()),
      ),
      error: (error, _) => ModernErrorState(
        message: error.toString(),
        onRetry: onRetry,
      ),
    );
  }
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(salesTrendProvider);
    final granularity = ref.watch(effectiveTrendGranularityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          child: ModernSectionHeader(title: 'Tren Penjualan & Laba'),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        _Section(
          child: Row(
            children: [
              for (final option in TrendGranularity.values) ...[
                ModernChip(
                  label: option.label,
                  selected: granularity == option,
                  onSelected: (_) => ref
                      .read(trendGranularityProvider.notifier)
                      .state = option,
                ),
                const SizedBox(width: AppDimensions.spacing8),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        _Section(
          child: ModernCard.outlined(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SalesTrendLegend(),
                const SizedBox(height: AppDimensions.spacing16),
                _AsyncBlock<List<SalesTrendPoint>>(
                  value: trendAsync,
                  onRetry: () => ref.invalidate(salesTrendProvider),
                  loadingHeight: 220,
                  builder: (points) => SalesTrendLineChart(points: points),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComparisonSection extends ConsumerWidget {
  const _ComparisonSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonAsync = ref.watch(periodComparisonProvider);

    return _Section(
      child: _AsyncBlock(
        value: comparisonAsync,
        onRetry: () => ref.invalidate(periodComparisonProvider),
        loadingHeight: 180,
        builder: (comparison) => PeriodComparisonCard(comparison: comparison),
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryDistributionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          child: ModernSectionHeader(title: 'Distribusi Kategori'),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _Section(
          child: ModernCard.outlined(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: _AsyncBlock(
              value: categoriesAsync,
              onRetry: () => ref.invalidate(categoryDistributionProvider),
              builder: (slices) => DistributionPieChart(
                centerLabel: 'Total',
                slices: [
                  for (var i = 0; i < slices.length; i++)
                    PieSliceData(
                      label: slices[i].categoryName,
                      value: slices[i].revenue,
                      // Fall back to the palette when a category has no colour
                      // of its own, so slices stay visually distinct.
                      color: slices[i].isUncategorised
                          ? AppColors.textTertiary
                          : ColorUtils.fromHex(
                              slices[i].categoryColor,
                              fallback: ColorUtils.paletteAt(i),
                            ),
                      detail: '${slices[i].quantitySold} item terjual',
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentSection extends ConsumerWidget {
  const _PaymentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentDistributionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          child: ModernSectionHeader(title: 'Metode Pembayaran'),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _Section(
          child: ModernCard.outlined(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: _AsyncBlock(
              value: paymentsAsync,
              onRetry: () => ref.invalidate(paymentDistributionProvider),
              builder: (slices) => Column(
                children: [
                  DistributionPieChart(
                    centerLabel: 'Total',
                    slices: [
                      for (var i = 0; i < slices.length; i++)
                        PieSliceData(
                          label: slices[i].label,
                          value: slices[i].total,
                          color: ColorUtils.paletteAt(i),
                          detail: '${slices[i].transactionCount} transaksi',
                        ),
                    ],
                  ),
                  if (slices.totalUnpaid > 0) ...[
                    const SizedBox(height: AppDimensions.spacing8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: AppDimensions.iconSmall,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppDimensions.spacing8),
                          Expanded(
                            child: Text(
                              'Belum dibayar: '
                              '${CurrencyFormatter.format(slices.totalUnpaid)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeatmapSection extends ConsumerWidget {
  const _HeatmapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(hourlyHeatmapProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          child: ModernSectionHeader(
            title: 'Pola Jam Ramai',
            subtitle: 'Ketuk kotak untuk melihat detail',
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _Section(
          child: ModernCard.outlined(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: _AsyncBlock(
              value: heatmapAsync,
              onRetry: () => ref.invalidate(hourlyHeatmapProvider),
              builder: (heatmap) => HourlySalesHeatmap(heatmap: heatmap),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        _Section(
          child: _AsyncBlock(
            value: heatmapAsync,
            onRetry: () => ref.invalidate(hourlyHeatmapProvider),
            loadingHeight: 120,
            builder: (heatmap) => PeakHoursCard(heatmap: heatmap),
          ),
        ),
      ],
    );
  }
}

class _DayOfWeekSection extends ConsumerWidget {
  const _DayOfWeekSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(hourlyHeatmapProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(
          child: ModernSectionHeader(title: 'Perbandingan Hari'),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _Section(
          child: ModernCard.outlined(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: _AsyncBlock(
              value: heatmapAsync,
              onRetry: () => ref.invalidate(hourlyHeatmapProvider),
              loadingHeight: 180,
              builder: (heatmap) => DayOfWeekBarChart(heatmap: heatmap),
            ),
          ),
        ),
      ],
    );
  }
}
