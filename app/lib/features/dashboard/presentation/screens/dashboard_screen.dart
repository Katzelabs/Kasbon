import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_gradients.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/gradient_summary_card.dart';
import '../widgets/low_stock_alert.dart';
import '../widgets/sales_summary_card.dart';
import '../../../../config/routes/app_router.dart';

/// Main dashboard/home screen for the KASBON POS app.
///
/// ## Wider never shows less
///
/// This screen used to fork into a phone build and a "tablet" build, and the
/// tablet build was the *smaller* of the two: it dropped the welcome banner and
/// replaced the whole sales summary card - headline figure, comparison badge,
/// profit and transaction stats - with a row of four compact tiles. Dragging a
/// window from 890dp to 910dp therefore removed content from the screen.
///
/// So there is one body now, and each tier adds to the one below it:
///
/// * **compact / medium** - banner, sales summary, low-stock alert, 2-3 category
///   columns. What the phone build always showed.
/// * **expanded** - the same, plus the four-tile stats row above it, and the
///   summary and the alert side by side instead of stacked.
/// * **large** - the same again, with the category menu pulled up into that row
///   as a third column, so the fold holds the whole dashboard.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Beranda',
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh the dashboard data
          ref.invalidate(dashboardSummaryProvider);
          // Wait for the new data to load
          await ref.read(dashboardSummaryProvider.future);
        },
        child: const _DashboardBody(),
      ),
    );
  }
}

/// The one dashboard body, laid out for the room it is given.
class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    // A dashboard is one of the few screens that genuinely uses the extra
    // width - four stat tiles and a three-column fold - so it gets the widest
    // clamp rather than the default. Past 1440 the tiles just get emptier.
    return ModernContentColumn.wide(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // The bottom inset is guarded by shellBottomInset, which is zero at the
        // tiers that have a rail instead of a bottom bar.
        padding: EdgeInsets.only(
          top: AppDimensions.spacing16,
          bottom: AppDimensions.spacing24 + context.shellBottomInset,
        ),
        child: Builder(
          // Inside the content column, so the tier read here is the clamped
          // width and not the window's - which is the whole point of measuring
          // in `build` rather than branching once at the top of the screen.
          builder: (context) => _sections(context, ref, summaryAsync),
        ),
      ),
    );
  }

  Widget _sections(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<DashboardSummary> summaryAsync,
  ) {
    final tier = context.breakpoint;

    // The alert is data-dependent in a way the layout has to know about before
    // it can build the Row: with nothing low on stock there is no second column
    // and the summary card takes the whole width.
    final lowStockCount = summaryAsync.valueOrNull?.hasLowStock == true
        ? summaryAsync.valueOrNull!.lowStockCount
        : null;

    final summaryCard = summaryAsync.when(
      loading: () => const _SalesSummaryCardSkeleton(),
      error: (error, _) => ModernCard.elevated(
        padding: const EdgeInsets.all(AppDimensions.spacing20),
        child: ModernErrorState(
          message: 'Gagal memuat ringkasan',
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
        ),
      ),
      data: (summary) => SalesSummaryCard(
        summary: summary,
        onTap: () => context.go(AppRoutes.transactions),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // At every tier, including the ones that used to drop it.
        const _BannerSection(),
        const SizedBox(height: AppDimensions.spacing24),

        // The four-tile stats row is an *addition* at expanded and above, not
        // a replacement for the summary card the way it used to be.
        if (tier.atLeast(Breakpoint.expanded)) ...[
          summaryAsync.when(
            loading: () => const _SummaryStatsRowSkeleton(),
            error: (error, _) => const SizedBox.shrink(),
            data: (summary) => _SummaryStatsRow(summary: summary),
          ),
          const SizedBox(height: AppDimensions.spacing24),
        ],

        if (tier.isLarge)
          // Three columns: the summary, the alert, and the menu. Everything
          // above the fold on a desktop window.
          _ThreeColumnFold(
            summaryCard: summaryCard,
            lowStockCount: lowStockCount,
          )
        else ...[
          if (tier.isExpanded)
            _SummaryAndAlertRow(
              summaryCard: summaryCard,
              lowStockCount: lowStockCount,
            )
          else ...[
            summaryCard,
            if (lowStockCount != null) ...[
              const SizedBox(height: AppDimensions.spacing16),
              LowStockAlert(count: lowStockCount),
            ],
          ],
          const SizedBox(height: AppDimensions.spacing24),
          _CategorySection(
            crossAxisCount: context.responsive<int>(
              compact: 2,
              medium: 3,
              expanded: 4,
            ),
          ),
        ],
      ],
    );
  }
}

/// `expanded`: the summary card keeps most of the width, the alert docks beside
/// it. Falls back to a full-width card when there is nothing low on stock.
class _SummaryAndAlertRow extends StatelessWidget {
  const _SummaryAndAlertRow({
    required this.summaryCard,
    required this.lowStockCount,
  });

  final Widget summaryCard;
  final int? lowStockCount;

  @override
  Widget build(BuildContext context) {
    if (lowStockCount == null) return summaryCard;

    return Row(
      // The alert is a two-line strip and the card is much taller; stretching
      // it to match would make a 200dp-high warning banner.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: summaryCard),
        const SizedBox(width: AppDimensions.spacing16),
        Expanded(flex: 1, child: LowStockAlert(count: lowStockCount!)),
      ],
    );
  }
}

/// `large`: summary, alert and the category menu across one fold.
class _ThreeColumnFold extends StatelessWidget {
  const _ThreeColumnFold({
    required this.summaryCard,
    required this.lowStockCount,
  });

  final Widget summaryCard;
  final int? lowStockCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: summaryCard),
        if (lowStockCount != null) ...[
          const SizedBox(width: AppDimensions.spacing16),
          Expanded(flex: 1, child: LowStockAlert(count: lowStockCount!)),
        ],
        const SizedBox(width: AppDimensions.spacing24),
        // Two columns of category cards rather than the four it gets when the
        // menu spans the screen: this column is roughly two fifths of the
        // width, and a four-across grid inside it would be unreadably narrow.
        const Expanded(flex: 2, child: _CategorySection(crossAxisCount: 2)),
      ],
    );
  }
}

/// Banner section for promotions or quick info
class _BannerSection extends StatelessWidget {
  const _BannerSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        gradient: AppGradients.primaryCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
        boxShadow: AppShadows.glow(AppColors.primary),
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Selamat Datang!',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  'Kelola bisnis Anda dengan mudah\ndan efisien bersama KASBON',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary stats row, shown at `expanded` and above in addition to the card.
class _SummaryStatsRow extends StatelessWidget {
  final DashboardSummary summary;

  const _SummaryStatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GradientSummaryCard.success(
            value: CurrencyFormatter.formatCompact(summary.todaySales),
            label: 'Penjualan Hari Ini',
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing16),
        Expanded(
          child: GradientSummaryCard.primary(
            value: CurrencyFormatter.formatCompact(summary.todayProfit),
            label: 'Laba Hari Ini',
            icon: Icons.monetization_on,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing16),
        Expanded(
          child: GradientSummaryCard.info(
            value: summary.transactionCount.toString(),
            label: 'Transaksi Hari Ini',
            icon: Icons.receipt_long,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing16),
        Expanded(
          child: GradientSummaryCard.warning(
            value: summary.lowStockCount.toString(),
            label: 'Stok Rendah',
            icon: Icons.warning_amber,
          ),
        ),
      ],
    );
  }
}

/// Skeleton loader for summary stats row
class _SummaryStatsRowSkeleton extends StatelessWidget {
  const _SummaryStatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ModernSkeleton(
      child: Row(
        children: [
          Expanded(child: _SkeletonStatCard()),
          SizedBox(width: AppDimensions.spacing16),
          Expanded(child: _SkeletonStatCard()),
          SizedBox(width: AppDimensions.spacing16),
          Expanded(child: _SkeletonStatCard()),
          SizedBox(width: AppDimensions.spacing16),
          Expanded(child: _SkeletonStatCard()),
        ],
      ),
    );
  }
}

/// Placeholder shaped like a [GradientSummaryCard].
class _SkeletonStatCard extends StatelessWidget {
  const _SkeletonStatCard();

  @override
  Widget build(BuildContext context) {
    return const ModernSkeletonBox(
      height: 100,
      borderRadius: BorderRadius.all(
        Radius.circular(AppDimensions.radiusLarge),
      ),
    );
  }
}

/// Skeleton loader for sales summary card
///
/// Mirrors the real card's structure - icon, title, headline figure,
/// comparison badge, then the two-up stat row - so nothing jumps when the
/// data arrives.
class _SalesSummaryCardSkeleton extends StatelessWidget {
  const _SalesSummaryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ModernCard.elevated(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      child: ModernSkeleton(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                ModernSkeletonBox(
                  width: 36,
                  height: 36,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppDimensions.radiusMedium),
                  ),
                ),
                SizedBox(width: AppDimensions.spacing12),
                ModernSkeletonBox.text(width: 150, height: 20),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            const ModernSkeletonBox.text(width: 180, height: 32),
            const SizedBox(height: AppDimensions.spacing8),
            const ModernSkeletonBox.text(width: 120, height: 24),
            const SizedBox(height: AppDimensions.spacing16),
            const ModernDivider(),
            const SizedBox(height: AppDimensions.spacing16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    children: [
                      ModernSkeletonBox.text(width: 60, height: 12),
                      SizedBox(height: AppDimensions.spacing8),
                      ModernSkeletonBox.text(width: 90, height: 18),
                    ],
                  ),
                ),
                Container(height: 60, width: 1, color: AppColors.border),
                const Expanded(
                  child: Column(
                    children: [
                      ModernSkeletonBox.text(width: 70, height: 12),
                      SizedBox(height: AppDimensions.spacing8),
                      ModernSkeletonBox.text(width: 40, height: 18),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Menu Kategori" heading and its grid.
///
/// Heading and grid travel together because at `large` the pair becomes a
/// column of the fold rather than a full-width band under it.
class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.crossAxisCount});

  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    const categories = DefaultMenuCategories.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu Kategori',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppDimensions.spacing12,
            mainAxisSpacing: AppDimensions.spacing12,
            childAspectRatio: 2.5,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryGridCard(
              label: category.label,
              icon: category.icon,
              backgroundColor: category.backgroundColor,
              iconColor: category.iconColor,
              onTap: () {
                context.go(category.routePath);
              },
            );
          },
        ),
      ],
    );
  }
}
