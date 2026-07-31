import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A sign-in or sign-up failure, stated inline and left on screen.
///
/// This replaces the error toast both screens used to raise. A toast is the
/// wrong shape for this failure: it is the only feedback the user gets, it
/// leaves after a few seconds, and it leaves *while* they are re-reading the
/// password they just typed. "Email atau password salah" then has to be
/// remembered rather than read.
///
/// It sits directly above the submit button rather than at the top of the
/// form, because that is where the eye already is at the moment the attempt
/// fails - on a phone the top of a five-field form is off screen by then.
///
/// [liveRegion] is what makes a screen reader announce the message when it
/// appears, rather than only when the banner is reached by traversal.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  /// The failure to show, or null when the last attempt did not fail.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: AppDimensions.iconMedium,
              color: AppColors.error,
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
