import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import 'modern_table_column.dart';

/// A Modern-styled data table with selection, scrolling, and bulk actions
///
/// Example usage:
/// ```dart
/// ModernDataTable<Product>(
///   columns: [
///     ModernTableColumn(
///       id: 'name',
///       header: Text('Name'),
///       cellBuilder: (product) => Text(product.name),
///       flex: 2,
///     ),
///   ],
///   items: products,
///   idGetter: (product) => product.id,
///   selectedIds: selectedIds,
///   onSelectionChanged: (id, selected) { ... },
///   onSelectAll: (selectAll) { ... },
/// )
/// ```
class ModernDataTable<T> extends StatelessWidget {
  const ModernDataTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idGetter,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.onSelectAll,
    this.onRowTap,
    this.showCheckboxColumn = true,
    this.rowHeight = 56.0,
    this.headerHeight = 48.0,
    this.emptyState,
    this.isLoading = false,
    this.horizontalScrollController,
    this.checkboxColumnWidth = 48.0,
    this.showHorizontalScrollbar = false,
    this.shrinkWrap = false,
  });

  /// Column definitions
  final List<ModernTableColumn<T>> columns;

  /// Data items to display
  final List<T> items;

  /// Function to extract unique ID from item
  final String Function(T item) idGetter;

  /// Currently selected item IDs
  final Set<String> selectedIds;

  /// Callback when selection changes (single item)
  final void Function(String id, bool selected)? onSelectionChanged;

  /// Callback when select all is toggled
  final void Function(bool selectAll)? onSelectAll;

  /// Callback when a row is tapped (not checkbox)
  final void Function(T item)? onRowTap;

  /// Whether to show checkbox column
  final bool showCheckboxColumn;

  /// Height of each data row
  final double rowHeight;

  /// Height of header row
  final double headerHeight;

  /// Widget to show when items is empty
  final Widget? emptyState;

  /// Whether data is loading
  final bool isLoading;

  /// Controller for horizontal scrolling
  final ScrollController? horizontalScrollController;

  /// Width of checkbox column
  final double checkboxColumnWidth;

  /// Whether to show horizontal scrollbar (useful for mobile)
  final bool showHorizontalScrollbar;

  /// Whether to shrink wrap the table to fit content exactly
  /// When true, the table will not be scrollable vertically
  /// Useful when the parent already provides a fixed height
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (items.isEmpty) {
      return emptyState ?? const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columnWidths = _calculateColumnWidths(availableWidth);
        final totalColumnsWidth = columnWidths.values.fold<double>(
          showCheckboxColumn ? checkboxColumnWidth : 0,
          (sum, width) => sum + width,
        );

        // Use the larger of available width or total columns width
        final tableWidth =
            totalColumnsWidth > availableWidth ? totalColumnsWidth : null;

        // Calculate exact data rows height when shrinkWrap is enabled
        // Height = (items * rowHeight) + ((items - 1) * separatorHeight)
        final dataRowsHeight = shrinkWrap
            ? (items.length * rowHeight) + (items.length - 1)
            : null;

        Widget scrollContent = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: horizontalScrollController,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: tableWidth ?? availableWidth,
            child: Column(
              mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
              children: [
                // Header
                _buildHeader(columnWidths),
                // Divider
                const Divider(
                    height: 1, thickness: 1, color: AppColors.border),
                // Data rows - use explicit height when shrinkWrap, Expanded otherwise
                if (shrinkWrap)
                  SizedBox(
                    height: dataRowsHeight,
                    child: _buildDataRows(columnWidths),
                  )
                else
                  Expanded(
                    child: _buildDataRows(columnWidths),
                  ),
              ],
            ),
          ),
        );

        // Wrap with Scrollbar if enabled
        if (showHorizontalScrollbar && horizontalScrollController != null) {
          scrollContent = Scrollbar(
            controller: horizontalScrollController,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(3),
            child: scrollContent,
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: scrollContent,
          ),
        );
      },
    );
  }

  Map<String, double> _calculateColumnWidths(double availableWidth) {
    final widths = <String, double>{};
    double remainingWidth =
        availableWidth - (showCheckboxColumn ? checkboxColumnWidth : 0);
    int totalFlex = 0;

    // First pass: calculate fixed widths and total flex
    for (final column in columns) {
      if (column.width != null) {
        widths[column.id] = column.width!;
        remainingWidth -= column.width!;
      } else if (column.flex != null) {
        totalFlex += column.flex!;
      } else {
        widths[column.id] = column.minWidth;
        remainingWidth -= column.minWidth;
      }
    }

    // Second pass: distribute remaining width to flex columns
    if (totalFlex > 0 && remainingWidth > 0) {
      for (final column in columns) {
        if (column.width == null && column.flex != null) {
          final flexWidth = (remainingWidth * column.flex!) / totalFlex;
          widths[column.id] = flexWidth.clamp(
            column.minWidth,
            column.maxWidth ?? double.infinity,
          );
        }
      }
    }

    return widths;
  }

  Widget _buildHeader(Map<String, double> columnWidths) {
    return Container(
      height: headerHeight,
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          // Spacer to align with selection indicator in data rows
          const SizedBox(width: 3),
          // Select all checkbox (adjusted width to match data rows)
          if (showCheckboxColumn)
            SizedBox(
              width: checkboxColumnWidth - 3,
              child: Center(
                child: Checkbox(
                  value: _isAllSelected,
                  tristate: _isPartiallySelected,
                  onChanged: onSelectAll != null
                      ? (value) => onSelectAll!(value ?? false)
                      : null,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
              ),
            ),
          // Column headers
          ...columns.map((column) {
            final width = columnWidths[column.id] ?? column.minWidth;
            return SizedBox(
              width: width,
              child: Padding(
                padding: column.padding ??
                    const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing12),
                child: Align(
                  alignment: column.effectiveHeaderAlignment,
                  child: DefaultTextStyle(
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    child: column.header,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataRows(Map<String, double> columnWidths) {
    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 1,
        color: AppColors.borderLight,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final itemId = idGetter(item);
        final isSelected = selectedIds.contains(itemId);

        return _buildRow(
          item: item,
          itemId: itemId,
          isSelected: isSelected,
          columnWidths: columnWidths,
        );
      },
    );
  }

  Widget _buildRow({
    required T item,
    required String itemId,
    required bool isSelected,
    required Map<String, double> columnWidths,
  }) {
    return Material(
      color: isSelected ? AppColors.primaryContainer : AppColors.surface,
      child: InkWell(
        onTap: onRowTap != null ? () => onRowTap!(item) : null,
        child: SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              // Selection indicator (3px colored bar on left)
              Container(
                width: 3,
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              // Row checkbox (adjusted width to account for selection indicator)
              if (showCheckboxColumn)
                SizedBox(
                  width: checkboxColumnWidth - 3, // Subtract selection indicator width
                  child: Center(
                    child: Checkbox(
                      value: isSelected,
                      onChanged: onSelectionChanged != null
                          ? (value) =>
                              onSelectionChanged!(itemId, value ?? false)
                          : null,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSmall),
                      ),
                    ),
                  ),
                ),
              // Cell contents
              ...columns.map((column) {
                final width = columnWidths[column.id] ?? column.minWidth;
                return SizedBox(
                  width: width,
                  child: Padding(
                    padding: column.padding ??
                        const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing12),
                    child: Align(
                      alignment: column.alignment,
                      child: DefaultTextStyle(
                        style: AppTextStyles.bodyMedium,
                        child: column.cellBuilder(item),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isAllSelected =>
      items.isNotEmpty &&
      items.every((item) => selectedIds.contains(idGetter(item)));

  bool get _isPartiallySelected =>
      items.any((item) => selectedIds.contains(idGetter(item))) &&
      !_isAllSelected;
}
