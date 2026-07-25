import 'package:flutter/material.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_gradients.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A modern summary card with gradient background
///
/// Used for displaying key statistics like:
/// - Total products
/// - Low stock count
/// - Daily revenue
/// - etc.
class GradientSummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Gradient gradient;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const GradientSummaryCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.gradient = AppGradients.primaryCard,
    this.onTap,
    this.width,
    this.height,
  });

  /// Primary gradient card (blue to purple)
  factory GradientSummaryCard.primary({
    required String value,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return GradientSummaryCard(
      value: value,
      label: label,
      icon: icon,
      gradient: AppGradients.primaryCard,
      onTap: onTap,
      width: width,
      height: height,
    );
  }

  /// Success gradient card (green)
  factory GradientSummaryCard.success({
    required String value,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return GradientSummaryCard(
      value: value,
      label: label,
      icon: icon,
      gradient: AppGradients.successCard,
      onTap: onTap,
      width: width,
      height: height,
    );
  }

  /// Warning gradient card (amber)
  factory GradientSummaryCard.warning({
    required String value,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return GradientSummaryCard(
      value: value,
      label: label,
      icon: icon,
      gradient: AppGradients.warningCard,
      onTap: onTap,
      width: width,
      height: height,
    );
  }

  /// Error gradient card (red)
  factory GradientSummaryCard.error({
    required String value,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return GradientSummaryCard(
      value: value,
      label: label,
      icon: icon,
      gradient: AppGradients.errorCard,
      onTap: onTap,
      width: width,
      height: height,
    );
  }

  /// Info gradient card (blue)
  factory GradientSummaryCard.info({
    required String value,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return GradientSummaryCard(
      value: value,
      label: label,
      icon: icon,
      gradient: AppGradients.infoCard,
      onTap: onTap,
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
        child: Container(
          width: width,
          height: height ?? 100,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (icon != null)
                    Icon(
                      icon,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: AppDimensions.iconXLarge,
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
