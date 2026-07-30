import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/daily_sales.dart';

/// Days revealed per step in the [showAll] form.
///
/// `showAll` used to mean "build one tile per day in the range", so picking
/// "Tahun Ini" laid out 365 tiles in a plain `Column` inside the report's
/// scroll view - all of them built, none of them on screen. A month at a time
/// is more than a reader takes in at once and cheap to extend.
const int _dayPageSize = 30;

/// List widget for displaying daily sales breakdown
class DailySalesList extends StatefulWidget {
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
  State<DailySalesList> createState() => _DailySalesListState();
}

class _DailySalesListState extends State<DailySalesList> {
  int _visibleCount = _dayPageSize;

  @override
  void didUpdateWidget(DailySalesList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A new period is a new list; keeping the old depth would open it
    // part-scrolled for no reason the reader can see.
    if (oldWidget.dailySales != widget.dailySales) {
      _visibleCount = _dayPageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailySales = widget.dailySales;
    final showAll = widget.showAll;

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

    final displayedSales = showAll
        ? sortedSales.take(_visibleCount).toList()
        : sortedSales.take(5).toList();

    final hasMore = showAll && displayedSales.length < sortedSales.length;

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
          if (hasMore) ...[
            const ModernDivider(),
            InkWell(
              onTap: () => setState(() => _visibleCount += _dayPageSize),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Muat Lebih Banyak '
                      '(${displayedSales.length}/${sortedSales.length} hari)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing4),
                    const Icon(
                      Icons.expand_more,
                      color: AppColors.primary,
                      size: AppDimensions.iconMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!showAll &&
              sortedSales.length > 5 &&
              widget.onViewAll != null) ...[
            const ModernDivider(),
            InkWell(
              onTap: widget.onViewAll,
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
                    color:
                        isToday ? AppColors.primary : AppColors.textSecondary,
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
