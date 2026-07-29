import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/date_range_provider.dart';

/// Horizontal chip selector for date range selection
class DateRangeSelector extends ConsumerWidget {
  /// Inset around the chip row.
  ///
  /// Defaults to the screen gutter, which is what every caller wanted while
  /// each report screen padded its own sections by hand. A screen wrapped in
  /// [ModernContentColumn] already has that gutter and passes `EdgeInsets.zero`
  /// instead, or the chips end up indented twice.
  final EdgeInsetsGeometry padding;

  const DateRangeSelector({
    super.key,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimensions.spacing16,
    ),
  });

  /// Open the range picker and apply the result.
  ///
  /// The picker's end date is inclusive but the report range is half-open, so
  /// a day is added to `to`. Without that, picking "1 - 5 Juli" would silently
  /// drop everything sold on the 5th.
  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(dateRangeProvider);
    final now = DateTime.now();

    final picked = await ModernDateRangePicker.show(
      context: context,
      initialRange: DateTimeRange(
        start: current.from,
        end: current.to.subtract(const Duration(days: 1)),
      ),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked == null || !context.mounted) return;

    ref.read(dateRangeProvider.notifier).selectCustom(
          DateTime(picked.start.year, picked.start.month, picked.start.day),
          DateTime(picked.end.year, picked.end.month, picked.end.day)
              .add(const Duration(days: 1)),
        );
  }

  /// Label for the custom chip, showing the picked range once one is active.
  String _customLabel(DateRangeState state) {
    if (state.type != DateRangeType.custom) return 'Kustom';

    final format = DateFormat('d MMM', 'id_ID');
    final inclusiveEnd = state.to.subtract(const Duration(days: 1));
    final isSingleDay = state.from.year == inclusiveEnd.year &&
        state.from.month == inclusiveEnd.month &&
        state.from.day == inclusiveEnd.day;

    return isSingleDay
        ? format.format(state.from)
        : '${format.format(state.from)} - ${format.format(inclusiveEnd)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(dateRangeProvider);

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
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
              onTap: () =>
                  ref.read(dateRangeProvider.notifier).selectThisWeek(),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            _buildChip(
              context: context,
              label: 'Bulan Ini',
              isSelected: dateRange.type == DateRangeType.thisMonth,
              onTap: () =>
                  ref.read(dateRangeProvider.notifier).selectThisMonth(),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            _buildChip(
              context: context,
              label: _customLabel(dateRange),
              icon: Icons.calendar_today_rounded,
              isSelected: dateRange.type == DateRangeType.custom,
              onTap: () => _pickCustomRange(context, ref),
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
    IconData? icon,
  }) {
    return ModernChip(
      label: label,
      icon: icon,
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}
