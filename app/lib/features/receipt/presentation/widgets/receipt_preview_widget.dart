import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';

/// Widget to display a text-based receipt preview
///
/// Displays the receipt text in a monospace font within a styled container
/// that mimics the look of a thermal printer receipt.
///
/// Example:
/// ```dart
/// ReceiptPreviewWidget(
///   receiptText: receiptGenerator.generate(...),
/// )
/// ```
class ReceiptPreviewWidget extends StatelessWidget {
  const ReceiptPreviewWidget({
    super.key,
    required this.receiptText,
    this.backgroundColor,
    this.textColor,
    this.fontSize = 11,
    this.padding,
    this.showShadow = true,
  });

  /// The receipt text to display
  final String receiptText;

  /// Background color of the receipt (default: white)
  final Color? backgroundColor;

  /// Text color (default: dark gray/black)
  final Color? textColor;

  /// Font size for the receipt text (default: 11 for monospace readability)
  final double fontSize;

  /// Custom padding
  final EdgeInsets? padding;

  /// Whether to show shadow effect
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.surface;
    final txtColor = textColor ?? AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Receipt "paper" header decoration (gradient effect)
            Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade300,
                    bgColor,
                  ],
                ),
              ),
            ),
            // Receipt content
            Padding(
              padding: padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                    vertical: AppDimensions.spacing12,
                  ),
              child: SelectableText(
                receiptText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: fontSize,
                  color: txtColor,
                  height: 1.3,
                  letterSpacing: 0,
                ),
              ),
            ),
            // Receipt "paper" footer decoration (perforated edge effect)
            Container(
              height: 12,
              color: bgColor,
              child: CustomPaint(
                size: const Size(double.infinity, 12),
                painter: _PerforatedEdgePainter(
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for perforated edge effect at bottom of receipt
///
/// Creates a dashed line that mimics the perforated edge of thermal paper.
class _PerforatedEdgePainter extends CustomPainter {
  final Color color;

  _PerforatedEdgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
