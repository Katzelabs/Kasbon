import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../utils/modern_variants.dart';

/// Pagination controls widget with page number buttons and Previous/Next buttons.
///
/// Features:
/// - Clickable page number buttons with smart ellipsis for many pages
/// - First and last page always visible in page buttons for quick navigation
/// - Responsive design: 3 visible pages on mobile, 5 on tablet/desktop
/// - Display text shown above pagination buttons
///
/// Example:
/// ```dart
/// ModernPaginationControls(
///   currentPage: 3,
///   totalPages: 10,
///   displayText: '21-30 dari 100 produk',
///   onPageChanged: (page) => ref.read(filterProvider.notifier).goToPage(page),
///   onPreviousPage: () => ref.read(filterProvider.notifier).previousPage(),
///   onNextPage: () => ref.read(filterProvider.notifier).nextPage(),
/// )
/// ```
class ModernPaginationControls extends StatelessWidget {
  const ModernPaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPreviousPage,
    this.onNextPage,
    this.onPageChanged,
    this.displayText,
    this.size = ModernSize.medium,
    this.showPageNumbers = true,
    this.maxVisiblePages,
    this.hapticFeedback = true,
  });

  /// Current page number (1-indexed)
  final int currentPage;

  /// Total number of pages
  final int totalPages;

  /// Callback when previous page button is pressed
  final VoidCallback? onPreviousPage;

  /// Callback when next page button is pressed
  final VoidCallback? onNextPage;

  /// Callback when a specific page is selected
  final void Function(int page)? onPageChanged;

  /// Optional display text (e.g., "1-8 dari 45 produk")
  final String? displayText;

  /// Size variant for the controls
  final ModernSize size;

  /// Whether to show page number buttons
  final bool showPageNumbers;

  /// Maximum visible page buttons before using ellipsis
  /// If null, auto-detects: 3 on mobile, 5 on tablet/desktop
  final int? maxVisiblePages;

  /// Whether to provide haptic feedback on button press
  final bool hapticFeedback;

  bool get _hasPrevious => currentPage > 1;
  bool get _hasNext => currentPage < totalPages;

  double get _buttonSize {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.buttonHeightSmall;
      case ModernSize.medium:
        return 36.0;
      case ModernSize.large:
        return AppDimensions.buttonHeightMedium;
    }
  }

  double get _iconSize {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.iconSmall;
      case ModernSize.medium:
        return AppDimensions.iconMedium;
      case ModernSize.large:
        return AppDimensions.iconLarge;
    }
  }

  void _triggerHaptic() {
    if (hapticFeedback) HapticFeedback.lightImpact();
  }

  void _handlePrevious() {
    if (_hasPrevious && onPreviousPage != null) {
      _triggerHaptic();
      onPreviousPage!();
    }
  }

  void _handleNext() {
    if (_hasNext && onNextPage != null) {
      _triggerHaptic();
      onNextPage!();
    }
  }

  void _handlePageTap(int page) {
    if (page != currentPage && onPageChanged != null) {
      _triggerHaptic();
      onPageChanged!(page);
    }
  }

  /// Get effective max visible pages based on screen size
  int _getEffectiveMaxVisiblePages(BuildContext context) {
    if (maxVisiblePages != null) return maxVisiblePages!;
    return context.isMobile ? 3 : 5;
  }

  /// Build list of page numbers to display with ellipsis
  List<_PageItem> _buildPageItems(int maxVisible) {
    if (totalPages <= 0) return [];

    // If total pages fit within max visible, show all
    if (totalPages <= maxVisible) {
      return List.generate(
        totalPages,
        (i) => _PageItem.page(i + 1),
      );
    }

    final items = <_PageItem>[];
    final halfVisible = (maxVisible - 2) ~/ 2; // Pages around current (excluding first/last)

    // Always add first page
    items.add(_PageItem.page(1));

    // Calculate range around current page
    int rangeStart = currentPage - halfVisible;
    int rangeEnd = currentPage + halfVisible;

    // Adjust range if it extends beyond bounds
    if (rangeStart <= 2) {
      // Near the beginning: show first few pages
      rangeStart = 2;
      rangeEnd = maxVisible - 1;
    } else if (rangeEnd >= totalPages - 1) {
      // Near the end: show last few pages
      rangeEnd = totalPages - 1;
      rangeStart = totalPages - maxVisible + 2;
    }

    // Ensure range is valid
    rangeStart = rangeStart.clamp(2, totalPages - 1);
    rangeEnd = rangeEnd.clamp(2, totalPages - 1);

    // Add ellipsis before range if needed
    if (rangeStart > 2) {
      items.add(_PageItem.ellipsis());
    }

    // Add pages in range
    for (int i = rangeStart; i <= rangeEnd; i++) {
      items.add(_PageItem.page(i));
    }

    // Add ellipsis after range if needed
    if (rangeEnd < totalPages - 1) {
      items.add(_PageItem.ellipsis());
    }

    // Always add last page (if not already included)
    if (totalPages > 1) {
      items.add(_PageItem.page(totalPages));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveMaxVisible = _getEffectiveMaxVisiblePages(context);
    final pageItems = _buildPageItems(effectiveMaxVisible);
    final canNavigate = onPageChanged != null;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacing12,
        horizontal: AppDimensions.spacing16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display text (e.g., "1-8 dari 45 produk")
          if (displayText != null) ...[
            Text(
              displayText!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacing8),
          ],

          // Pagination controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous button
              _PaginationButton(
                icon: Icons.chevron_left,
                onPressed: _hasPrevious ? _handlePrevious : null,
                size: _buttonSize,
                iconSize: _iconSize,
                tooltip: 'Halaman sebelumnya',
              ),

              // Page number buttons
              if (showPageNumbers && totalPages > 0) ...[
                const SizedBox(width: AppDimensions.spacing8),
                ...pageItems.map((item) {
                  if (item.isEllipsis) {
                    return _EllipsisIndicator(size: _buttonSize);
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing2,
                    ),
                    child: _PageNumberButton(
                      pageNumber: item.page!,
                      isSelected: item.page == currentPage,
                      onPressed: canNavigate ? () => _handlePageTap(item.page!) : null,
                      size: _buttonSize,
                    ),
                  );
                }),
                const SizedBox(width: AppDimensions.spacing8),
              ],

              // Next button
              _PaginationButton(
                icon: Icons.chevron_right,
                onPressed: _hasNext ? _handleNext : null,
                size: _buttonSize,
                iconSize: _iconSize,
                tooltip: 'Halaman berikutnya',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Represents a page item (either a page number or ellipsis)
class _PageItem {
  final int? page;
  final bool isEllipsis;

  const _PageItem._({this.page, this.isEllipsis = false});

  factory _PageItem.page(int pageNumber) => _PageItem._(page: pageNumber);
  factory _PageItem.ellipsis() => const _PageItem._(isEllipsis: true);
}

/// Internal pagination button widget for navigation icons
class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.iconSize,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;

  bool get _isDisabled => onPressed == null;

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _isDisabled ? Colors.transparent : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: AppColors.border,
          width: AppDimensions.inputBorderWidth,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: _isDisabled ? AppColors.textDisabled : AppColors.primary,
        ),
      ),
    );

    button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: button,
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// Page number button widget
class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({
    required this.pageNumber,
    required this.isSelected,
    required this.onPressed,
    required this.size,
  });

  final int pageNumber;
  final bool isSelected;
  final VoidCallback? onPressed;
  final double size;

  bool get _isDisabled => onPressed == null && !isSelected;

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: AppDimensions.inputBorderWidth,
        ),
      ),
      child: Center(
        child: Text(
          '$pageNumber',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.onPrimary
                : (_isDisabled ? AppColors.textDisabled : AppColors.primary),
          ),
        ),
      ),
    );

    button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelected ? null : onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: button,
      ),
    );

    return Tooltip(
      message: 'Halaman $pageNumber',
      child: button,
    );
  }
}

/// Ellipsis indicator between page numbers
class _EllipsisIndicator extends StatelessWidget {
  const _EllipsisIndicator({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.6,
      height: size,
      child: Center(
        child: Text(
          '...',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
