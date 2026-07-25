import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled quantity stepper for increment/decrement operations
///
/// Example:
/// ```dart
/// ModernQuantityStepper(
///   value: 1,
///   onChanged: (v) => setState(() => _quantity = v),
/// )
/// ModernQuantityStepper.compact(
///   value: 5,
///   onChanged: (v) => print('New value: $v'),
/// )
/// ```
class ModernQuantityStepper extends StatelessWidget {
  const ModernQuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue = 999,
    this.step = 1,
    this.size = ModernSize.medium,
    this.showBorder = true,
  });

  /// Creates a compact quantity stepper for inline use
  const ModernQuantityStepper.compact({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue = 999,
    this.step = 1,
    this.showBorder = false,
  }) : size = ModernSize.small;

  final int value;
  final ValueChanged<int> onChanged;
  final int minValue;
  final int maxValue;
  final int step;
  final ModernSize size;
  final bool showBorder;

  bool get _canDecrement => value > minValue;
  bool get _canIncrement => value < maxValue;

  double get _height {
    switch (size) {
      case ModernSize.small:
        return AppDimensions.buttonHeightSmall;
      case ModernSize.medium:
        return AppDimensions.buttonHeightMedium;
      case ModernSize.large:
        return AppDimensions.buttonHeightLarge;
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

  double get _buttonWidth {
    switch (size) {
      case ModernSize.small:
        return 28;
      case ModernSize.medium:
        return 36;
      case ModernSize.large:
        return 44;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: showBorder
            ? Border.all(color: AppColors.border, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            icon: Icons.remove,
            enabled: _canDecrement,
            onTap: () => onChanged(value - step),
          ),
          Container(
            constraints: BoxConstraints(minWidth: _buttonWidth),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing8,
            ),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: size == ModernSize.small
                  ? AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    )
                  : AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
          _buildButton(
            icon: Icons.add,
            enabled: _canIncrement,
            onTap: () => onChanged(value + step),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          width: _buttonWidth,
          height: _height,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: _iconSize,
            color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
