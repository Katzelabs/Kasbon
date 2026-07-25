import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled chip for selection and filtering
///
/// Example:
/// ```dart
/// ModernChip(
///   label: 'Makanan',
///   selected: isSelected,
///   onSelected: (selected) => _onCategorySelected(selected),
/// )
/// ```
class ModernChip extends StatelessWidget {
  const ModernChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.avatar,
    this.deleteIcon,
    this.onDeleted,
    this.enabled = true,
    this.size = ModernSize.medium,
  });

  /// Creates a filter chip
  const ModernChip.filter({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.enabled = true,
    this.size = ModernSize.medium,
  })  : avatar = null,
        deleteIcon = null,
        onDeleted = null;

  /// Creates an input chip with delete button
  factory ModernChip.input({
    Key? key,
    required String label,
    Widget? avatar,
    VoidCallback? onDeleted,
    bool enabled = true,
    ModernSize size = ModernSize.medium,
  }) {
    return ModernChip(
      key: key,
      label: label,
      avatar: avatar,
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      enabled: enabled,
      size: size,
    );
  }

  /// The chip label text
  final String label;

  /// Whether the chip is selected
  final bool selected;

  /// Callback when selection changes
  final void Function(bool selected)? onSelected;

  /// Optional leading icon
  final IconData? icon;

  /// Optional avatar widget
  final Widget? avatar;

  /// Optional delete icon
  final Widget? deleteIcon;

  /// Callback when delete is pressed
  final VoidCallback? onDeleted;

  /// Whether the chip is enabled
  final bool enabled;

  /// The size of the chip
  final ModernSize size;

  double get _height {
    switch (size) {
      case ModernSize.small:
        return 28;
      case ModernSize.medium:
        return 36;
      case ModernSize.large:
        return 44;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case ModernSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case ModernSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case ModernSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = onSelected != null || onDeleted != null;
    final effectiveEnabled = enabled && isInteractive;

    final backgroundColor = selected
        ? AppColors.primaryContainer
        : effectiveEnabled
            ? AppColors.surfaceVariant
            : AppColors.surfaceVariant.withValues(alpha: 0.5);

    final foregroundColor = selected
        ? AppColors.primary
        : effectiveEnabled
            ? AppColors.textPrimary
            : AppColors.textDisabled;

    final borderColor = selected ? AppColors.primary : AppColors.border;

    Widget chip = Container(
      height: _height,
      padding: _padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar != null) ...[
            avatar!,
            const SizedBox(width: AppDimensions.spacing8),
          ],
          if (icon != null) ...[
            Icon(
              icon,
              size: size == ModernSize.small ? 14 : 18,
              color: foregroundColor,
            ),
            const SizedBox(width: AppDimensions.spacing4),
          ],
          Text(
            label,
            style: (size == ModernSize.small
                    ? AppTextStyles.labelSmall
                    : AppTextStyles.labelMedium)
                .copyWith(color: foregroundColor),
          ),
          if (deleteIcon != null && onDeleted != null) ...[
            const SizedBox(width: AppDimensions.spacing4),
            GestureDetector(
              onTap: enabled ? onDeleted : null,
              child: IconTheme(
                data: IconThemeData(
                  color: foregroundColor,
                  size: size == ModernSize.small ? 14 : 18,
                ),
                child: deleteIcon!,
              ),
            ),
          ],
        ],
      ),
    );

    if (onSelected != null && enabled) {
      chip = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected!(!selected),
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
          child: chip,
        ),
      );
    }

    return chip;
  }
}

/// A group of chips for multi-select
class ModernChipGroup extends StatelessWidget {
  const ModernChipGroup({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.size = ModernSize.medium,
    this.spacing = AppDimensions.spacing8,
    this.scrollable = true,
  });

  /// The chip items
  final List<ModernChipItem> items;

  /// The currently selected index
  final int selectedIndex;

  /// Callback when selection changes
  final void Function(int index) onSelected;

  /// The size of the chips
  final ModernSize size;

  /// Spacing between chips
  final double spacing;

  /// Whether the chips are scrollable
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final chips = items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return ModernChip(
        label: item.label,
        icon: item.icon,
        selected: index == selectedIndex,
        onSelected: (_) => onSelected(index),
        size: size,
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .expand((chip) => [chip, SizedBox(width: spacing)])
              .toList()
            ..removeLast(),
        ),
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: chips,
    );
  }
}

/// Data class for chip items
class ModernChipItem {
  const ModernChipItem({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;
}
