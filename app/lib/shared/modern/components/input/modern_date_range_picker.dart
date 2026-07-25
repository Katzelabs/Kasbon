import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../button/modern_button.dart';
import '../data_display/modern_chip.dart';
import 'modern_calendar.dart';

/// Quick preset options for date range selection
enum DateRangePreset {
  last7Days('7 Hari'),
  last30Days('30 Hari'),
  thisMonth('Bulan Ini'),
  lastMonth('Bulan Lalu');

  final String label;
  const DateRangePreset(this.label);

  DateTimeRange get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case DateRangePreset.last7Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case DateRangePreset.last30Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case DateRangePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );
      case DateRangePreset.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
        return DateTimeRange(
          start: lastMonth,
          end: lastDayOfLastMonth,
        );
    }
  }
}

/// A modern date range picker dialog with dual calendar view.
///
/// Features:
/// - Quick preset options (7 days, 30 days, this month, last month)
/// - Dual calendar view on tablet, tabbed view on mobile
/// - Range highlighting
/// - Custom styling matching the app theme
class ModernDateRangePicker extends StatefulWidget {
  /// The initially selected date range
  final DateTimeRange? initialRange;

  /// The earliest selectable date
  final DateTime firstDate;

  /// The latest selectable date
  final DateTime lastDate;

  const ModernDateRangePicker({
    super.key,
    this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  /// Shows the date range picker dialog and returns the selected range
  static Future<DateTimeRange?> show({
    required BuildContext context,
    DateTimeRange? initialRange,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: context.isMobile ? AppDimensions.spacing16 : AppDimensions.spacing24,
          vertical: AppDimensions.spacing24,
        ),
        child: ModernDateRangePicker(
          initialRange: initialRange,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
      ),
    );
  }

  @override
  State<ModernDateRangePicker> createState() => _ModernDateRangePickerState();
}

class _ModernDateRangePickerState extends State<ModernDateRangePicker>
    with SingleTickerProviderStateMixin {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late DateTime _startCalendarMonth;
  late DateTime _endCalendarMonth;
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange?.start;
    _endDate = widget.initialRange?.end;

    final now = DateTime.now();
    _startCalendarMonth = _startDate ?? now;
    _endCalendarMonth = _endDate ?? now;

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onPresetSelected(DateRangePreset preset) {
    final range = preset.range;
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
      _startCalendarMonth = range.start;
      _endCalendarMonth = range.end;
    });
  }

  void _onStartDateSelected(DateTime date) {
    setState(() {
      _startDate = date;
      // If end date is before start date, clear it
      if (_endDate != null && _endDate!.isBefore(date)) {
        _endDate = null;
      }
    });
    // On mobile, switch to end date tab
    if (context.isMobile) {
      _tabController.animateTo(1);
    }
  }

  void _onEndDateSelected(DateTime date) {
    setState(() {
      // If date is before start date, swap them
      if (_startDate != null && date.isBefore(_startDate!)) {
        _endDate = _startDate;
        _startDate = date;
      } else {
        _endDate = date;
      }
    });
  }

  void _onConfirm() {
    if (_startDate != null && _endDate != null) {
      Navigator.of(context).pop(DateTimeRange(start: _startDate!, end: _endDate!));
    }
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? double.infinity : 700,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 1, color: AppColors.divider),
          _buildPresetChips(),
          const Divider(height: 1, color: AppColors.divider),
          Flexible(
            child: isMobile ? _buildMobileCalendars() : _buildTabletCalendars(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _buildSelectedRange(),
          const Divider(height: 1, color: AppColors.divider),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Pilih Rentang Tanggal',
            style: AppTextStyles.h4,
          ),
          IconButton(
            onPressed: _onCancel,
            icon: const Icon(Icons.close),
            iconSize: AppDimensions.iconLarge,
            color: AppColors.textSecondary,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
      child: Row(
        children: DateRangePreset.values.map((preset) {
          final isSelected = _isPresetSelected(preset);
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacing8),
            child: ModernChip(
              label: preset.label,
              selected: isSelected,
              onSelected: (_) => _onPresetSelected(preset),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isPresetSelected(DateRangePreset preset) {
    if (_startDate == null || _endDate == null) return false;
    final range = preset.range;
    return _isSameDay(_startDate!, range.start) && _isSameDay(_endDate!, range.end);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMobileCalendars() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab bar
        Container(
          color: AppColors.surfaceVariant,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(_startDate != null ? _formatDate(_startDate) : 'Mulai'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(_endDate != null ? _formatDate(_endDate) : 'Selesai'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Tab views
        Flexible(
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: ModernCalendar(
                  displayedMonth: _startCalendarMonth,
                  onMonthChanged: (month) => setState(() => _startCalendarMonth = month),
                  selectedDate: _startDate,
                  onDateSelected: _onStartDateSelected,
                  rangeStart: _startDate,
                  rangeEnd: _endDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  title: 'Tanggal Mulai',
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: ModernCalendar(
                  displayedMonth: _endCalendarMonth,
                  onMonthChanged: (month) => setState(() => _endCalendarMonth = month),
                  selectedDate: _endDate,
                  onDateSelected: _onEndDateSelected,
                  rangeStart: _startDate,
                  rangeEnd: _endDate,
                  firstDate: _startDate ?? widget.firstDate,
                  lastDate: widget.lastDate,
                  title: 'Tanggal Selesai',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletCalendars() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Start date calendar
          Expanded(
            child: ModernCalendar(
              displayedMonth: _startCalendarMonth,
              onMonthChanged: (month) => setState(() => _startCalendarMonth = month),
              selectedDate: _startDate,
              onDateSelected: _onStartDateSelected,
              rangeStart: _startDate,
              rangeEnd: _endDate,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              title: 'Tanggal Mulai',
            ),
          ),
          const SizedBox(width: AppDimensions.spacing24),
          // End date calendar
          Expanded(
            child: ModernCalendar(
              displayedMonth: _endCalendarMonth,
              onMonthChanged: (month) => setState(() => _endCalendarMonth = month),
              selectedDate: _endDate,
              onDateSelected: _onEndDateSelected,
              rangeStart: _startDate,
              rangeEnd: _endDate,
              firstDate: _startDate ?? widget.firstDate,
              lastDate: widget.lastDate,
              title: 'Tanggal Selesai',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedRange() {
    final hasSelection = _startDate != null && _endDate != null;
    final rangeText = hasSelection
        ? '${_formatDate(_startDate)} - ${_formatDate(_endDate)}'
        : 'Pilih tanggal mulai dan selesai';

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: AppDimensions.iconMedium,
            color: hasSelection ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: Text(
              rangeText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: hasSelection ? AppColors.textPrimary : AppColors.textTertiary,
                fontWeight: hasSelection ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final canConfirm = _startDate != null && _endDate != null;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ModernButton.outline(
            onPressed: _onCancel,
            child: const Text('Batal'),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          ModernButton.primary(
            onPressed: canConfirm ? _onConfirm : null,
            child: const Text('Pilih'),
          ),
        ],
      ),
    );
  }
}
