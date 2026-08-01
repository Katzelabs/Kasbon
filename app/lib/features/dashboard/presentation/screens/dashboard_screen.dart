import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_gradients.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../providers/dashboard_analytics_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/dashboard_analytics_section.dart';
import '../widgets/gradient_summary_card.dart';
import '../widgets/low_stock_alert.dart';
import '../widgets/sales_summary_card.dart';
import '../widgets/setup_checklist_card.dart';
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
/// * **compact** - banner, sales summary, low-stock alert, the analytics band
///   (trend + top sellers), then the category menu.
/// * **medium** - the same, minus the category menu, plus the payment mix in the
///   band. The menu goes because this is the first tier with a navigation rail,
///   and the rail carries every destination the grid did - see
///   [_CategorySection]. The payment mix moves into the room that frees.
/// * **expanded** - the same, plus the four-tile stats row, the summary and the
///   alert side by side, and the trend spanning the full width above the two
///   smaller blocks.
/// * **large** - the same content in two columns: the week on the left, today on
///   the right. See [_DesktopTwoColumn].
///
/// ## "Wider never shows less" is about capability, not widget count
///
/// The rule that shaped this screen was literal for a while - each tier had to
/// render everything the tier below it rendered - and that was the right rule
/// while the thing being dropped was *content*. The category menu is not
/// content; it is a duplicate route. Dropping it at `medium` removes no
/// destination, because the rail that appears at exactly that tier is what makes
/// it redundant. The test suite pins the refined rule: every route in
/// [DefaultMenuCategories] must be reachable from the shell's rail at the tiers
/// where the grid is gone.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Beranda',
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: const _DashboardBody(),
      ),
    );
  }

  /// Re-fetch everything on the screen, and hold the spinner until it has all
  /// landed.
  ///
  /// Awaiting only the summary - which is what this did while the summary was
  /// the only request - ends the gesture while three charts are still
  /// skeletons, so the pull reads as having done nothing.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardSummaryProvider);
    invalidateDashboardAnalytics(ref);

    await Future.wait([
      _settled(ref.read(dashboardSummaryProvider.future)),
      _settled(ref.read(dashboardSalesTrendProvider.future)),
      _settled(ref.read(dashboardTopProductsProvider.future)),
      _settled(ref.read(dashboardPaymentMixProvider.future)),
    ]);
  }

  /// Await [future], discarding its result and any error.
  ///
  /// Every block on this screen renders its own error state, so a failure has
  /// already been reported by the time the spinner stops. Letting it escape
  /// here would instead surface as an unhandled exception from the refresh
  /// gesture, and one failing request would abandon the other three.
  static Future<void> _settled(Future<void> future) async {
    try {
      await future;
    } catch (_) {
      // Owned by the block that made the request.
    }
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

        // Above the numbers on purpose: on a shop that has not finished setting
        // up, the numbers are all zero and this is the only thing on the page
        // worth acting on. Renders nothing once complete or dismissed.
        const SetupChecklistCard(),

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
          // Two columns: a week of analytics, and a sidebar of today.
          _DesktopTwoColumn(
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

          // Above the category menu where the menu still exists, deliberately:
          // a week of sales outranks a grid of links.
          const DashboardAnalyticsSection(),

          // Only on a phone. See [_CategorySection].
          if (tier.isCompact) ...[
            const SizedBox(height: AppDimensions.spacing24),
            const _CategorySection(crossAxisCount: 2),
          ],
        ],
      ],
    );
  }
}

/// `large`: analytics on the left, today on the right.
///
/// ## What this replaced, and why
///
/// The old `large` layout was three columns - summary, stock alert, category
/// menu - with the analytics band below it. The menu took two fifths of that
/// row, and it was a duplicate: from `medium` upward the shell's rail carries
/// every destination the grid did (`modern_app_shell.dart` says as much), so a
/// desktop window spent its widest, most valuable row on links that were already
/// two clicks closer in the rail beside it.
///
/// Dropping the menu left a hole rather than a saving. Letting the remaining two
/// columns expand into it would have stretched the summary card to ~890dp to
/// show a headline figure and two stats. So the fold was rebuilt around the
/// distinction that actually matters on this screen: **the week on the left, the
/// day on the right.**
///
/// ## The split is 2:1
///
/// Measured on a 1600dp window (1376dp of content after the clamp and padding):
/// the analytics column gets 901dp and the sidebar 451dp, which puts the trend
/// chart at 869dp - up from 634dp under the three-across band it replaces, and
/// the widest this chart has ever been given at this tier.
///
/// The payment mix sits in the sidebar rather than under the trend because
/// moving it left would leave the sidebar hundreds of dp short of the column
/// beside it.
///
/// ## Keeping the two columns level
///
/// Balance is not free here, and the first version of this layout did not have
/// it: 792dp of analytics column against 1021dp of sidebar, a 229dp ragged edge.
/// Two changes closed it, both of which are legibility wins in their own right at
/// this width - a taller trend plot (869x260 rather than 869x200, which was flat
/// enough to iron out a real swing in takings) and eight top sellers instead of
/// five (the card is 901dp across; five rows left two thirds of it empty). The
/// columns now measure 1002dp against 1021dp.
class _DesktopTwoColumn extends StatelessWidget {
  const _DesktopTwoColumn({
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
        const DashboardCell(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The header sits over this column rather than over the whole
              // row: the sidebar beside it is today's figures, and a
              // "7 Hari" heading spanning both would mislabel them.
              DashboardAnalyticsHeader(),
              SizedBox(height: AppDimensions.spacing12),
              // Taller chart and a longer list than the narrower tiers get.
              // Both are legibility wins on their own - a 869dp chart at the
              // default height is a 4.3:1 plot, and a 901dp card with five rows
              // is mostly empty - and together they close the gap between this
              // column and the sidebar, which measured 792dp against 1021dp
              // before they went in.
              DashboardTrendCard(
                chartHeight: DashboardTrendCard.tallChartHeight,
              ),
              SizedBox(height: AppDimensions.spacing20),
              DashboardTopProductsCard(
                maxRows: DashboardTopProductsCard.maxRowsWide,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacing24),
        DashboardCell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The sidebar gets a header of its own for two reasons. It names
              // the period, which is the whole point of the pair of headings -
              // "7 Hari" on the left, "Hari Ini" on the right, so neither column
              // can be read as the other. And it keeps the two columns level:
              // without it the sidebar would start 46dp below the trend card
              // beside it, which reads as a layout slip rather than a choice.
              //
              // The subtitle is the comparison the cards below actually make,
              // not the date - the header band already carries the date, and
              // repeating it twice on one screen is the kind of duplication this
              // pass exists to remove.
              const ModernSectionHeader(
                title: 'Hari Ini',
                subtitle: 'Dibanding kemarin',
              ),
              const SizedBox(height: AppDimensions.spacing12),
              summaryCard,
              if (lowStockCount != null) ...[
                const SizedBox(height: AppDimensions.spacing16),
                LowStockAlert(count: lowStockCount!),
              ],
              const SizedBox(height: AppDimensions.spacing20),
              // Labelled with its own period - it is the one seven-day card in
              // a column of same-day ones.
              const DashboardPaymentMixCard(showPeriod: true),
            ],
          ),
        ),
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

/// The header band: who this is and what day the figures below describe.
///
/// ## What changed, and why
///
/// This was a fixed 160dp gradient carrying a greeting and two lines of
/// marketing copy - "Kelola bisnis Anda dengan mudah dan efisien bersama
/// KASBON" - which the owner of the shop had already read once, on the day they
/// installed the app. On a desktop window that is the top sixth of the first
/// fold spent on a slogan, directly above the figures someone opened the app to
/// see.
///
/// The slogan is now the trading date, which is information the screen was
/// missing: every card below says "Hari Ini" and none of them said which day
/// that was. The band also sizes to its content instead of to 160dp, so it
/// reclaims roughly 70dp at the wide tiers where the date sits beside the
/// greeting rather than under it.
class _BannerSection extends StatelessWidget {
  const _BannerSection();

  @override
  Widget build(BuildContext context) {
    // Business wall-clock, not the device clock: on a phone set to another zone
    // `DateTime.now()` can name a different day than the shop is trading in,
    // and this band would then disagree with every figure under it.
    final today = DateFormat(
      'EEEE, d MMMM yyyy',
      'id_ID',
    ).format(BusinessTime.now());

    // From `medium` up the greeting and the date fit on one row, which takes
    // the band from 136dp to 91dp - measured, not guessed. Only a phone is too
    // narrow to hold both, and there it stacks.
    final sideBySide = context.isAtLeast(Breakpoint.medium);

    const greeting = _BannerGreeting();
    final date = _BannerDateChip(label: today);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.primaryCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
        boxShadow: AppShadows.glow(AppColors.primary),
      ),
      // The decorative circles hang past the band's edges; clipping to the same
      // radius as the decoration keeps them inside the rounded corners rather
      // than being cut square by the Stack.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
        child: Stack(
          children: [
            const Positioned(
              right: -30,
              top: -50,
              child: _BannerCircle(size: 160, opacity: 0.10),
            ),
            const Positioned(
              right: 70,
              bottom: -60,
              child: _BannerCircle(size: 120, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              child: sideBySide
                  ? Row(
                      children: [
                        const Expanded(child: greeting),
                        const SizedBox(width: AppDimensions.spacing16),
                        date,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        greeting,
                        const SizedBox(height: AppDimensions.spacing12),
                        date,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerGreeting extends StatelessWidget {
  const _BannerGreeting();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Selamat Datang!',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          'Ringkasan bisnis Anda hari ini',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

/// The trading date, as a pill on the gradient.
class _BannerDateChip extends StatelessWidget {
  final String label;

  const _BannerDateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: AppDimensions.iconSmall,
            color: Colors.white,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the band's decorative circles.
class _BannerCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _BannerCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// Summary stats row, shown at `expanded` and above in addition to the card.
///
/// Every tile routes somewhere. They used to be four decorative rectangles -
/// [GradientSummaryCard] has taken an `onTap` all along and none of them passed
/// one, so the most prominent, most obviously tappable objects on the widest
/// layouts did nothing when tapped. Each now goes to the screen that explains
/// the figure it is showing.
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
            onTap: () => context.go(AppRoutes.reportsSales),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing16),
        Expanded(
          child: GradientSummaryCard.primary(
            value: CurrencyFormatter.formatCompact(summary.todayProfit),
            label: 'Laba Hari Ini',
            icon: Icons.monetization_on,
            onTap: () => context.go(AppRoutes.reportsProfit),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing16),
        Expanded(
          child: GradientSummaryCard.info(
            value: summary.transactionCount.toString(),
            label: 'Transaksi Hari Ini',
            icon: Icons.receipt_long,
            onTap: () => context.go(AppRoutes.transactions),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing16),
        Expanded(
          child: GradientSummaryCard.warning(
            value: summary.lowStockCount.toString(),
            label: 'Stok Rendah',
            icon: Icons.warning_amber,
            onTap: () => context.go(AppRoutes.products),
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

/// The "Menu Kategori" heading and its grid. **`compact` only.**
///
/// ## Why it stops at the phone
///
/// This grid is a second copy of the app's navigation, and whether that copy is
/// worth its space depends entirely on what chrome the shell is showing:
///
/// | Tier      | Shell chrome            | Reaches                                     |
/// |-----------|-------------------------|---------------------------------------------|
/// | `compact` | Bottom bar, 4 items     | Beranda, Produk, Transaksi, Pengaturan      |
/// | `medium`+ | Rail, 7 items           | ...plus Kasir, Hutang, Laporan              |
///
/// On a phone the grid is load-bearing: Hutang and Laporan have *no* other
/// route, which `modern_app_shell.dart` states outright - "POS, Hutang and
/// Laporan are unreachable from here and live behind the FAB and the dashboard".
/// From `medium` upward the rail carries all seven, so every destination in
/// [DefaultMenuCategories] is already one click away in the chrome beside this
/// grid, and rendering it again spends the widest row on the screen restating
/// the navigation.
///
/// The one destination the rail does not carry is Dev Tools (`/dev`), which is
/// consequently unreachable by tap from `medium` up. That used to be the only
/// thing hiding it, which was worth roughly nothing on web - path URLs meant
/// `/dev/seed` was one typed address away in a shipped build. The route is now
/// registered only in debug (`AppPlatform.exposesDevTools`) and the grid drops
/// its tile to match, so in release there is no route to reach and no tile to
/// point at it.
///
/// Heading and grid travel together because the pair is placed as one unit.
class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.crossAxisCount});

  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final categories = DefaultMenuCategories.items;

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
