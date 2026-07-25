import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/daily_sales.dart';

/// List widget for displaying daily sales breakdown
class DailySalesList extends StatelessWidget {
  final List<DailySales> dailySales;
  final bool showAll;
  final VoidCallback? onViewAll;

  const DailySalesList({
    super.key,
    required this.dailySales,
    this.showAll = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Tidak Ada Data',
        message: 'Belum ada penjualan pada periode ini',
      );
    }

    // Sort by date descending (most recent first)
    final sortedSales = List<DailySales>.from(dailySales)
      ..sort((a, b) => b.date.compareTo(a.date));

    final displayedSales = showAll ? sortedSales : sortedSales.take(5).toList();

    return ModernCard.outlined(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ...displayedSales.asMap().entries.map((entry) {
            final isLast = entry.key == displayedSales.length - 1;
            return Column(
              children: [
                _buildDailyTile(entry.value),
                if (!isLast) const ModernDivider(),
              ],
            );
          }),
          if (!showAll && sortedSales.length > 5 && onViewAll != null) ...[
            const ModernDivider(),
            InkWell(
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lihat Semua (${sortedSales.length} hari)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing4),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                      size: AppDimensions.iconMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyTile(DailySales sales) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final isToday = _isToday(sales.date);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('d').format(sales.date),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isToday ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'id_ID').format(sales.date),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isToday ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Hari Ini' : dateFormat.format(sales.date),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  '${sales.transactionCount} transaksi',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(sales.revenue),
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
