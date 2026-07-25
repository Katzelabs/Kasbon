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
import '../providers/dashboard_provider.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/gradient_summary_card.dart';
import '../widgets/low_stock_alert.dart';
import '../widgets/sales_summary_card.dart';

/// Main dashboard/home screen for the KASBON POS app
///
/// Mobile layout:
/// - Banner section (promotional)
/// - Sales Summary Card (with real data)
/// - Low Stock Alert (if any)
/// - Menu Kategori grid (2 columns)
///
/// Tablet layout:
/// - Summary stats row (with real data)
/// - Menu Kategori grid (3-4 columns)
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
        child: context.isMobile
            ? const _MobileDashboard()
            : const _TabletDashboard(),
      ),
    );
  }
}

/// Mobile dashboard layout
class _MobileDashboard extends ConsumerWidget {
  const _MobileDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppDimensions.spacing16,
        bottom: AppDimensions.bottomNavHeight + AppDimensions.spacing24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner section
          const _BannerSection(),
          const SizedBox(height: AppDimensions.spacing24),

          // Sales Summary Card with loading/error states
          summaryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing16,
              ),
              child: _SalesSummaryCardSkeleton(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing16,
              ),
              child: ModernCard.elevated(
                padding: const EdgeInsets.all(AppDimensions.spacing20),
                child: ModernErrorState(
                  message: 'Gagal memuat ringkasan',
                  onRetry: () => ref.invalidate(dashboardSummaryProvider),
                ),
              ),
            ),
            data: (summary) => Column(
              children: [
                SalesSummaryCard(
                  summary: summary,
                  onTap: () => context.go('/transactions'),
                ),
                // Low Stock Alert (only if there are low stock products)
                if (summary.hasLowStock) ...[
                  const SizedBox(height: AppDimensions.spacing16),
                  LowStockAlert(count: summary.lowStockCount),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Menu Kategori
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            child: Text(
              'Menu Kategori',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Category Grid
          const _CategoryGrid(crossAxisCount: 2),
        ],
      ),
    );
  }
}

/// Tablet dashboard layout
class _TabletDashboard extends ConsumerWidget {
  const _TabletDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Stats Row with real data
          summaryAsync.when(
            loading: () => const _SummaryStatsRowSkeleton(),
            error: (error, _) => ModernCard.elevated(
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              child: ModernErrorState(
                message: 'Gagal memuat ringkasan',
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
              ),
            ),
            data: (summary) => _SummaryStatsRow(summary: summary),
          ),

          const SizedBox(height: AppDimensions.spacing32),

          // Menu Kategori
          Text(
            'Menu Kategori',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Category Grid (more columns on tablet)
          _CategoryGrid(
            crossAxisCount:
                context.gridColumns(mobile: 2, tablet: 3, desktop: 4),
          ),
        ],
      ),
    );
  }
}

/// Banner section for promotions or quick info
class _BannerSection extends StatelessWidget {
  const _BannerSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Container(
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
      ),
    );
  }
}

/// Summary stats row for tablet layout with real data
class _SummaryStatsRow extends StatelessWidget {
  final dynamic summary;

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

/// Category menu grid
class _CategoryGrid extends StatelessWidget {
  final int crossAxisCount;

  const _CategoryGrid({required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    const categories = DefaultMenuCategories.items;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: GridView.builder(
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
    );
  }
}
