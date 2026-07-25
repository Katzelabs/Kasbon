import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';

/// A Modern-styled divider with consistent theming
///
/// Example:
/// ```dart
/// ModernDivider()
/// ModernDivider.thin()
/// ModernDivider.thick()
/// ModernDivider.vertical(height: 24)
/// ```
class ModernDivider extends StatelessWidget {
  const ModernDivider({
    super.key,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  }) : _isVertical = false;

  const ModernDivider._vertical({
    super.key,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  }) : _isVertical = true;

  /// Creates a thin divider (0.5px)
  const ModernDivider.thin({
    super.key,
    this.indent,
    this.endIndent,
    this.color,
  })  : height = 1,
        thickness = 0.5,
        _isVertical = false;

  /// Creates a thick divider (2px)
  const ModernDivider.thick({
    super.key,
    this.indent,
    this.endIndent,
    this.color,
  })  : height = AppDimensions.spacing8,
        thickness = 2,
        _isVertical = false;

  /// Creates a vertical divider
  factory ModernDivider.vertical({
    Key? key,
    double? width,
    double? thickness,
    double? indent,
    double? endIndent,
    Color? color,
  }) {
    return ModernDivider._vertical(
      key: key,
      height: width,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color,
    );
  }

  /// Creates a divider with spacing above and below
  factory ModernDivider.spaced({
    Key? key,
    double spacing = AppDimensions.spacing16,
    double? thickness,
    double? indent,
    double? endIndent,
    Color? color,
  }) {
    return ModernDivider(
      key: key,
      height: spacing * 2,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color,
    );
  }

  /// The total height of the divider (includes spacing)
  final double? height;

  /// The thickness of the divider line
  final double? thickness;

  /// The indent from the leading edge
  final double? indent;

  /// The indent from the trailing edge
  final double? endIndent;

  /// The color of the divider
  final Color? color;

  /// Whether this is a vertical divider
  final bool _isVertical;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.divider;
    final effectiveThickness = thickness ?? 1.0;

    if (_isVertical) {
      return VerticalDivider(
        width: height,
        thickness: effectiveThickness,
        indent: indent,
        endIndent: endIndent,
        color: effectiveColor,
      );
    }

    return Divider(
      height: height,
      thickness: effectiveThickness,
      indent: indent,
      endIndent: endIndent,
      color: effectiveColor,
    );
  }
}
