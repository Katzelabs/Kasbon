import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../utils/modern_hover.dart';
import '../feedback/modern_loading.dart';
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
///
/// ## At compact width
///
/// A table needs horizontal room it does not have on a phone, and it will not
/// get any inside a 320dp master pane either. Pass [narrowBuilder] and the
/// table renders a list of cards there instead - same items, same selection,
/// same row taps, without the horizontal scroll that hides half the columns
/// behind a gesture nobody discovers.
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
    this.narrowBuilder,
    this.sortColumnId,
    this.sortAscending = true,
    this.onSort,
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

  /// Card renderer used instead of the table at [Breakpoint.compact].
  ///
  /// Receives whether the item is selected so the card can show it; the table
  /// still supplies the tap target and the hover state around it.
  final Widget Function(BuildContext context, T item, bool isSelected)?
      narrowBuilder;

  /// Id of the column the data is currently sorted by, if any.
  final String? sortColumnId;

  /// Direction of the current sort.
  final bool sortAscending;

  /// Called when a sortable column header is activated.
  ///
  /// Receives the column id and the direction being asked for - tapping the
  /// active column flips it, tapping another starts it ascending. Reordering
  /// the items is the caller's job; this widget renders whatever list it is
  /// given and never sorts behind the caller's back.
  final void Function(String columnId, bool ascending)? onSort;

  /// Whether the header should offer a sort control for [column].
  bool _isSortable(ModernTableColumn<T> column) =>
      column.sortable && onSort != null;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      // Was a raw CircularProgressIndicator - the one rule the widget library
      // states outright, broken inside the library itself.
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing32),
          child: ModernLoading(),
        ),
      );
    }

    if (items.isEmpty) {
      return emptyState ?? const SizedBox.shrink();
    }

    // Measures the space the table has, not the window: a table inside a
    // master pane is narrow however wide the monitor is.
    if (narrowBuilder != null && context.isCompact) {
      return _buildNarrowList(context);
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
        final dataRowsHeight =
            shrinkWrap ? (items.length * rowHeight) + (items.length - 1) : null;

        Widget scrollContent = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: horizontalScrollController,
          // Physics deliberately unset: AppScrollBehavior decides, so a table
          // bounces on iOS and clamps in a browser rather than bouncing
          // everywhere because it was written on a phone.
          child: SizedBox(
            width: tableWidth ?? availableWidth,
            child: Column(
              mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
              children: [
                // Header
                _buildHeader(context, columnWidths),
                // Divider
                const Divider(height: 1, thickness: 1, color: AppColors.border),
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

  Widget _buildHeader(BuildContext context, Map<String, double> columnWidths) {
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
              child: _buildHeaderCell(column),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(ModernTableColumn<T> column) {
    final isActiveSort = sortColumnId == column.id;

    Widget label = DefaultTextStyle(
      style: AppTextStyles.labelMedium.copyWith(
        color: isActiveSort ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      child: column.header,
    );

    if (!_isSortable(column)) {
      return Padding(
        padding: column.padding ??
            const EdgeInsets.symmetric(horizontal: AppDimensions.spacing12),
        child: Align(
          alignment: column.effectiveHeaderAlignment,
          child: label,
        ),
      );
    }

    // The arrow is always present on a sortable column, greyed until active.
    // Showing it only on the sorted column hides the fact that the others can
    // be sorted at all - the affordance has to exist before it is used.
    final indicator = Icon(
      isActiveSort
          ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.unfold_more,
      size: AppDimensions.iconSmall,
      color: isActiveSort ? AppColors.primary : AppColors.textTertiary,
    );

    return ModernHoverBuilder(
      builder: (context, isHovered, _) => Material(
        color: isHovered ? AppColors.borderLight : Colors.transparent,
        child: InkWell(
          // Tapping the active column flips it; any other column starts
          // ascending, which is what a reader expects of a fresh sort.
          onTap: () => onSort!(column.id, isActiveSort ? !sortAscending : true),
          child: Padding(
            padding: column.padding ??
                const EdgeInsets.symmetric(horizontal: AppDimensions.spacing12),
            child: Align(
              alignment: column.effectiveHeaderAlignment,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: label),
                  const SizedBox(width: AppDimensions.spacing4),
                  indicator,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The compact-tier form: [narrowBuilder] cards in place of the table.
  Widget _buildNarrowList(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacing8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(idGetter(item));
        final card = narrowBuilder!(context, item, isSelected);

        if (onRowTap == null) return card;

        return ModernHoverBuilder(
          child: card,
          builder: (context, isHovered, child) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onRowTap!(item),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              child: child,
            ),
          ),
        );
      },
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
    // Hover tint sits between the resting surface and the selected tint, so a
    // hovered row reads as "under the pointer" without being mistaken for one
    // that is already selected. A selected row does not change on hover - it
    // has already made its point.
    return ModernHoverBuilder(
      enabled: onRowTap != null,
      builder: (context, isHovered, _) => Material(
        color: isSelected
            ? AppColors.primaryContainer
            : (isHovered ? AppColors.surfaceVariant : AppColors.surface),
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
                    width: checkboxColumnWidth -
                        3, // Subtract selection indicator width
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
