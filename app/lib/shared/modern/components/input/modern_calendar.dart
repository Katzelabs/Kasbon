import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A modern calendar widget for date selection with range highlighting.
///
/// This widget displays a single month calendar with navigation controls,
/// support for date range selection, and visual feedback for selected dates.
class ModernCalendar extends StatefulWidget {
  /// The currently displayed month/year
  final DateTime displayedMonth;

  /// Callback when the displayed month changes
  final ValueChanged<DateTime>? onMonthChanged;

  /// The currently selected date
  final DateTime? selectedDate;

  /// Callback when a date is selected
  final ValueChanged<DateTime>? onDateSelected;

  /// Start date for range highlighting
  final DateTime? rangeStart;

  /// End date for range highlighting
  final DateTime? rangeEnd;

  /// The earliest selectable date
  final DateTime? firstDate;

  /// The latest selectable date
  final DateTime? lastDate;

  /// Optional title to display above the calendar
  final String? title;

  const ModernCalendar({
    super.key,
    required this.displayedMonth,
    this.onMonthChanged,
    this.selectedDate,
    this.onDateSelected,
    this.rangeStart,
    this.rangeEnd,
    this.firstDate,
    this.lastDate,
    this.title,
  });

  @override
  State<ModernCalendar> createState() => _ModernCalendarState();
}

class _ModernCalendarState extends State<ModernCalendar> {
  late DateTime _displayedMonth;

  // Indonesian day names (starting from Monday)
  static const List<String> _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.displayedMonth.year, widget.displayedMonth.month);
  }

  @override
  void didUpdateWidget(ModernCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.displayedMonth.year != oldWidget.displayedMonth.year ||
        widget.displayedMonth.month != oldWidget.displayedMonth.month) {
      _displayedMonth = DateTime(widget.displayedMonth.year, widget.displayedMonth.month);
    }
  }

  void _goToPreviousMonth() {
    final newMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    setState(() => _displayedMonth = newMonth);
    widget.onMonthChanged?.call(newMonth);
  }

  void _goToNextMonth() {
    final newMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    setState(() => _displayedMonth = newMonth);
    widget.onMonthChanged?.call(newMonth);
  }

  bool _isDateDisabled(DateTime date) {
    if (widget.firstDate != null && date.isBefore(widget.firstDate!)) {
      return true;
    }
    if (widget.lastDate != null && date.isAfter(widget.lastDate!)) {
      return true;
    }
    return false;
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInRange(DateTime date) {
    if (widget.rangeStart == null || widget.rangeEnd == null) return false;
    final start = widget.rangeStart!;
    final end = widget.rangeEnd!;
    return date.isAfter(start.subtract(const Duration(days: 1))) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  bool _isRangeStart(DateTime date) {
    return _isSameDay(date, widget.rangeStart);
  }

  bool _isRangeEnd(DateTime date) {
    return _isSameDay(date, widget.rangeEnd);
  }

  bool _isSelected(DateTime date) {
    return _isSameDay(date, widget.selectedDate);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'id_ID').format(_displayedMonth);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Optional title
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing8),
        ],
        // Month navigation
        _buildMonthNavigation(monthName),
        const SizedBox(height: AppDimensions.spacing12),
        // Day names header
        _buildDayNamesHeader(),
        const SizedBox(height: AppDimensions.spacing4),
        // Calendar grid
        _buildCalendarGrid(),
      ],
    );
  }

  Widget _buildMonthNavigation(String monthName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _goToPreviousMonth,
          icon: const Icon(Icons.chevron_left),
          iconSize: AppDimensions.iconLarge,
          color: AppColors.textPrimary,
          splashRadius: 20,
        ),
        Text(
          monthName,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          onPressed: _goToNextMonth,
          icon: const Icon(Icons.chevron_right),
          iconSize: AppDimensions.iconLarge,
          color: AppColors.textPrimary,
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildDayNamesHeader() {
    return Row(
      children: _dayNames.map((name) {
        return Expanded(
          child: Center(
            child: Text(
              name,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    // Monday = 1, Sunday = 7 in Dart
    // We want Monday as first day of week
    int startingWeekday = firstDayOfMonth.weekday - 1; // 0 = Monday, 6 = Sunday

    final List<Widget> rows = [];
    List<Widget> currentRow = [];

    // Add empty cells for days before the first day of month
    for (int i = 0; i < startingWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox.shrink()));
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      currentRow.add(Expanded(child: _buildDayCell(date)));

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    // Add remaining empty cells
    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add(const Expanded(child: SizedBox.shrink()));
      }
      rows.add(Row(children: currentRow));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        );
      }).toList(),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isDisabled = _isDateDisabled(date);
    final isSelected = _isSelected(date);
    final isToday = _isToday(date);
    final isInRange = _isInRange(date);
    final isRangeStart = _isRangeStart(date);
    final isRangeEnd = _isRangeEnd(date);

    // Determine background and text colors
    Color? backgroundColor;
    Color textColor = AppColors.textPrimary;
    BoxDecoration? decoration;

    if (isDisabled) {
      textColor = AppColors.textDisabled;
    } else if (isSelected || isRangeStart || isRangeEnd) {
      backgroundColor = AppColors.primary;
      textColor = Colors.white;
      decoration = BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      );
    } else if (isInRange) {
      backgroundColor = AppColors.primaryContainer;
      decoration = BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.horizontal(
          left: isRangeStart ? const Radius.circular(20) : Radius.zero,
          right: isRangeEnd ? const Radius.circular(20) : Radius.zero,
        ),
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 1.5),
      );
    }

    // Build the cell with range background
    Widget cell = Container(
      height: 40,
      alignment: Alignment.center,
      decoration: isInRange && !isRangeStart && !isRangeEnd
          ? const BoxDecoration(color: AppColors.primaryContainer)
          : null,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: decoration,
        child: Text(
          '${date.day}',
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor,
            fontWeight: (isSelected || isRangeStart || isRangeEnd) ? FontWeight.w600 : null,
          ),
        ),
      ),
    );

    if (isDisabled) {
      return cell;
    }

    return GestureDetector(
      onTap: () => widget.onDateSelected?.call(date),
      child: cell,
    );
  }
}
