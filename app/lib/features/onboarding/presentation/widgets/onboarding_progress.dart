import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// "Langkah 2 dari 3", with a segment per step.
///
/// A bar rather than a numbered stepper: three steps do not need chrome, and
/// the only question the user is actually asking is "how much more of this is
/// there". Segments answer that at a glance and stay legible at 320dp.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.currentIndex,
    required this.totalSteps,
  });

  /// Zero-based.
  final int currentIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Langkah ${currentIndex + 1} dari $totalSteps',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < totalSteps; i++) ...[
                if (i > 0) const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: AppDimensions.spacing4,
                    decoration: BoxDecoration(
                      color: i <= currentIndex
                          ? AppColors.primary
                          : AppColors.primaryDisabled,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Langkah ${currentIndex + 1} dari $totalSteps',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
