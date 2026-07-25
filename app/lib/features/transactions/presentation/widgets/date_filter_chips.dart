import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/date_filter.dart';
import '../providers/transactions_provider.dart';

/// Horizontal scrollable filter chips for date selection
class DateFilterChips extends ConsumerWidget {
  const DateFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(dateFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing8,
      ),
      child: Row(
        children: DateFilter.values.map((filter) {
          final isSelected = filter == selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacing8),
            child: ModernChip(
              label: filter.label,
              selected: isSelected,
              icon: filter == DateFilter.custom ? Icons.calendar_today : null,
              onSelected: (_) => _onFilterSelected(context, ref, filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _onFilterSelected(
    BuildContext context,
    WidgetRef ref,
    DateFilter filter,
  ) async {
    if (filter == DateFilter.custom) {
      // Show custom date range picker
      final now = DateTime.now();
      final picked = await ModernDateRangePicker.show(
        context: context,
        initialRange: ref.read(customDateRangeProvider),
        firstDate: DateTime(now.year - 1),
        lastDate: now,
      );

      if (picked != null) {
        ref.read(customDateRangeProvider.notifier).state = picked;
        ref.read(dateFilterProvider.notifier).state = DateFilter.custom;
      }
    } else {
      ref.read(dateFilterProvider.notifier).state = filter;
    }
  }
}
