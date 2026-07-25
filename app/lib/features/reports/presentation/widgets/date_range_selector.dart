import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/date_range_provider.dart';

/// Horizontal chip selector for date range selection
class DateRangeSelector extends ConsumerWidget {
  const DateRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(dateRangeProvider);

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          _buildChip(
            context: context,
            label: 'Hari Ini',
            isSelected: dateRange.type == DateRangeType.today,
            onTap: () => ref.read(dateRangeProvider.notifier).selectToday(),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          _buildChip(
            context: context,
            label: 'Minggu Ini',
            isSelected: dateRange.type == DateRangeType.thisWeek,
            onTap: () => ref.read(dateRangeProvider.notifier).selectThisWeek(),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          _buildChip(
            context: context,
            label: 'Bulan Ini',
            isSelected: dateRange.type == DateRangeType.thisMonth,
            onTap: () => ref.read(dateRangeProvider.notifier).selectThisMonth(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ModernChip(
      label: label,
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}
