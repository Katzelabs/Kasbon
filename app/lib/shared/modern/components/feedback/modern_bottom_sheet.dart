import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';

/// A Modern-styled bottom sheet with consistent theming
///
/// Example:
/// ```dart
/// ModernBottomSheet.show(
///   context,
///   title: 'Pilih Kategori',
///   child: CategoryList(),
/// );
/// ```
///
/// ## Width
///
/// Every modal path caps at [maxSheetWidth] and centres. A sheet is a column of
/// choices; stretched across a 1600dp monitor its title sits at one end of the
/// screen and its close button at the other.
///
/// ## Bottom sheet or side sheet
///
/// [showAdaptive] picks. Below `expanded` it is a bottom sheet, which is where
/// a thumb is. At `expanded` and above a bottom sheet is the wrong shape - it
/// covers the content it was opened from and travels the full height of a
/// desktop window to show four options - so it becomes a right-edge side sheet.
///
/// [show], [showScrollable] and [showActions] stay bottom sheets at every tier.
/// Callers that want the adaptive behaviour opt in; the ones that deliberately
/// want a sheet (an action list hanging off a thumb-reachable button) do not
/// have to opt out.
class ModernBottomSheet extends StatelessWidget {
  const ModernBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.padding,
    this.maxHeight,
  });

  /// The bottom sheet content
  final Widget child;

  /// Optional title
  final String? title;

  /// Whether to show the drag handle at the top
  final bool showDragHandle;

  /// Custom padding for the content
  final EdgeInsets? padding;

  /// Maximum height of the bottom sheet
  final double? maxHeight;

  /// Widest a modal sheet may grow before it centres instead.
  ///
  /// Matches [ContentLayout.dialogLarge]: a sheet and a dialog are the same
  /// kind of interruption and reading one after the other should not feel like
  /// changing rooms.
  static const double maxSheetWidth = ContentLayout.dialogLarge;

  /// Constraints applied to every modal sheet this class opens.
  static const BoxConstraints _sheetConstraints =
      BoxConstraints(maxWidth: maxSheetWidth);

  /// Shows a bottom sheet with the given child
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool showDragHandle = true,
    EdgeInsets? padding,
    double? maxHeight,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
    bool useSafeArea = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      constraints: _sheetConstraints,
      builder: (context) => ModernBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        padding: padding,
        maxHeight: maxHeight,
        child: child,
      ),
    );
  }

  /// Shows a bottom sheet on narrow windows and a right-edge side sheet on
  /// wide ones.
  ///
  /// The tier read is the *window*, not the container. A side sheet is window
  /// chrome: it docks to the window edge, so what matters is how wide the
  /// window is, not how wide the pane that opened it happens to be.
  ///
  /// Returns the same future either way, so a caller does not know or care
  /// which shape it got.
  static Future<T?> showAdaptive<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool showDragHandle = true,
    EdgeInsets? padding,
    double? maxHeight,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    double sideSheetWidth = ContentLayout.sideSheetWidth,
  }) {
    if (context.windowBreakpoint.below(Breakpoint.expanded)) {
      return show<T>(
        context,
        title: title,
        showDragHandle: showDragHandle,
        padding: padding,
        maxHeight: maxHeight,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        isScrollControlled: isScrollControlled,
        useSafeArea: useSafeArea,
        child: child,
      );
    }

    return _showSideSheet<T>(
      context,
      title: title,
      padding: padding,
      isDismissible: isDismissible,
      useSafeArea: useSafeArea,
      width: sideSheetWidth,
      child: child,
    );
  }

  /// [showAdaptive] for content that fills the sheet and scrolls inside it.
  ///
  /// The distinction is real, not a convenience: [showAdaptive] wraps its child
  /// in a scroll view and sizes to it, so a child containing an [Expanded] - a
  /// list with a pinned footer under it, say - gets an unbounded height and
  /// throws. This gives the child a bounded height instead and lets it manage
  /// its own scrolling.
  ///
  /// The builder's controller is the drag controller on the bottom-sheet path,
  /// which a `DraggableScrollableSheet` needs threaded into its inner scroll
  /// view for drag-to-expand to work. On the side-sheet path there is no drag,
  /// so it is null and the child scrolls normally.
  static Future<T?> showAdaptiveDraggable<T>(
    BuildContext context, {
    required Widget Function(BuildContext context, ScrollController? controller)
        builder,
    String? title,
    double initialChildSize = 0.7,
    double minChildSize = 0.4,
    double maxChildSize = 0.95,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = true,
    double sideSheetWidth = ContentLayout.sideSheetWidth,
  }) {
    if (context.windowBreakpoint.atLeast(Breakpoint.expanded)) {
      return _showSideSheet<T>(
        context,
        title: title,
        isDismissible: isDismissible,
        useSafeArea: useSafeArea,
        width: sideSheetWidth,
        scrollable: false,
        child: Builder(builder: (context) => builder(context, null)),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      constraints: _sheetConstraints,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXLarge),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: builder(context, scrollController),
        ),
      ),
    );
  }

  /// The wide-window half of [showAdaptive].
  ///
  /// A general dialog rather than a bottom sheet route, because the geometry is
  /// a dialog's: it does not drag, it does not snap, and it is anchored to an
  /// edge rather than to the bottom of the screen.
  static Future<T?> _showSideSheet<T>(
    BuildContext context, {
    required Widget child,
    required double width,
    String? title,
    EdgeInsets? padding,
    bool isDismissible = true,
    bool useSafeArea = true,
    bool scrollable = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ModernSideSheet(
          title: title,
          padding: padding,
          width: width,
          useSafeArea: useSafeArea,
          scrollable: scrollable,
          child: child,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }

  /// Shows a scrollable bottom sheet
  static Future<T?> showScrollable<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool showDragHandle = true,
    EdgeInsets? padding,
    double? maxHeight,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: _sheetConstraints,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ModernBottomSheet(
          title: title,
          showDragHandle: showDragHandle,
          padding: padding,
          maxHeight: maxHeight,
          child: SingleChildScrollView(
            controller: scrollController,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Shows an action sheet with a list of options
  static Future<int?> showActions(
    BuildContext context, {
    String? title,
    required List<ModernBottomSheetAction> actions,
    bool showCancel = true,
    String cancelLabel = 'Batal',
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: _sheetConstraints,
      builder: (context) => ModernBottomSheet(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              return _ActionItem(
                icon: action.icon,
                label: action.label,
                isDestructive: action.isDestructive,
                onTap: () => Navigator.of(context).pop(index),
              );
            }),
            if (showCancel) ...[
              const SizedBox(height: AppDimensions.spacing8),
              _ActionItem(
                label: cancelLabel,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The scope, not MediaQuery: a sheet is built against the root navigator,
    // where the scope reports the window anyway, and this keeps one way of
    // asking how much room there is rather than two.
    final effectiveMaxHeight = maxHeight ?? context.breakpointData.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          if (showDragHandle)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacing12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          // Title
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacing24,
                AppDimensions.spacing16,
                AppDimensions.spacing24,
                AppDimensions.spacing8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTextStyles.h4,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          // Content
          Flexible(
            child: Padding(
              padding: padding ??
                  const EdgeInsets.fromLTRB(
                    AppDimensions.spacing24,
                    AppDimensions.spacing16,
                    AppDimensions.spacing24,
                    AppDimensions.spacing24,
                  ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The wide-window form of a modal sheet: a fixed-width panel docked to the
/// right edge, full height.
///
/// Deliberately not draggable and without a drag handle. Both are touch
/// affordances, and this shape only appears where the pointer is a mouse.
class _ModernSideSheet extends StatelessWidget {
  const _ModernSideSheet({
    required this.child,
    required this.width,
    this.title,
    this.padding,
    this.useSafeArea = true,
    this.scrollable = true,
  });

  final Widget child;
  final double width;
  final String? title;
  final EdgeInsets? padding;
  final bool useSafeArea;

  /// Whether the panel scrolls the child, or hands it the remaining height and
  /// lets it scroll itself.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    Widget panel = Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.shadow,
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(AppDimensions.radiusXLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacing24,
                AppDimensions.spacing16,
                AppDimensions.spacing8,
                AppDimensions.spacing8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!, style: AppTextStyles.h4),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    padding: padding ??
                        const EdgeInsets.fromLTRB(
                          AppDimensions.spacing24,
                          AppDimensions.spacing16,
                          AppDimensions.spacing24,
                          AppDimensions.spacing24,
                        ),
                    child: child,
                  )
                : Padding(
                    padding: padding ?? EdgeInsets.zero,
                    child: child,
                  ),
          ),
        ],
      ),
    );

    if (useSafeArea) {
      panel = SafeArea(left: false, child: panel);
    }

    return Align(
      alignment: Alignment.centerRight,
      // Escape wired by hand rather than relied upon: showGeneralDialog gives
      // no dismiss action of its own, and a panel a mouse user cannot close
      // from the keyboard is worse than no panel.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: SizedBox(width: width, child: panel),
        ),
      ),
    );
  }
}

/// An action item for the bottom sheet action list
class ModernBottomSheetAction {
  const ModernBottomSheetAction({
    required this.label,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final IconData? icon;
  final bool isDestructive;
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.label,
    this.icon,
    this.isDestructive = false,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isDestructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing24,
            vertical: AppDimensions.spacing16,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: AppDimensions.iconLarge),
                const SizedBox(width: AppDimensions.spacing16),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
