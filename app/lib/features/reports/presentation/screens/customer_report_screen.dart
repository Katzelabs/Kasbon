import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/customer_analytics.dart';
import '../providers/analytics_provider.dart';
import '../widgets/customer_analytics_tile.dart';
import '../widgets/date_range_selector.dart';

/// Top customers and their lifetime value.
class CustomerReportScreen extends ConsumerWidget {
  const CustomerReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(topCustomersProvider);
    final bottomPadding =
        AppDimensions.spacing16 + context.shellBottomInset;

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Laporan Pelanggan',
        onProfileTap: () {},
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(topCustomersProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spacing16),
              const DateRangeSelector(),
              const SizedBox(height: AppDimensions.spacing24),
              customersAsync.when(
                data: (customers) => _buildContent(context, ref, customers),
                loading: () => const SizedBox(
                  height: 240,
                  child: Center(child: ModernLoading()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing16,
                  ),
                  child: ModernErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(topCustomersProvider),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<CustomerAnalytics> customers,
  ) {
    if (customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
        child: ModernEmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Belum Ada Data Pelanggan',
          // Explains the cause rather than just the symptom: the POS only
          // records a customer when a name is entered at checkout.
          message: 'Nama pelanggan hanya tercatat jika diisi saat transaksi. '
              'Isi nama pelanggan di kasir untuk melihat laporan ini.',
        ),
      );
    }

    final debtors = customers.withOutstandingDebt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
          child: Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Total Belanja',
                  value: CurrencyFormatter.format(customers.totalSpent),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _SummaryTile(
                  label: 'Pelanggan',
                  value: '${customers.length}',
                  color: AppColors.info,
                ),
              ),
              if (debtors.isNotEmpty) ...[
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Total Hutang',
                    value: CurrencyFormatter.formatCompact(
                      customers.totalOutstandingDebt,
                    ),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
          child: ModernSectionHeader(
            title: 'Pelanggan Teratas',
            subtitle: 'Berdasarkan total belanja pada periode ini',
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
          child: Column(
            children: [
              for (var i = 0; i < customers.length; i++)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppDimensions.spacing12),
                  child: CustomerAnalyticsTile(
                    customer: customers[i],
                    rank: i + 1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.filled(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
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
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
