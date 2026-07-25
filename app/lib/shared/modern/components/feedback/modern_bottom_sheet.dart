import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

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
      builder: (context) => ModernBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        padding: padding,
        maxHeight: maxHeight,
        child: child,
      ),
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
    final effectiveMaxHeight =
        maxHeight ?? MediaQuery.of(context).size.height * 0.9;

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
