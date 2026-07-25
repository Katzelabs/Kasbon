import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';

/// Shimmering placeholder for content that is still loading.
///
/// Wrap a skeleton *layout* in a single [ModernSkeleton] and fill it with
/// [ModernSkeletonBox] shapes. The sweep is driven by the one ancestor, so the
/// highlight travels across the whole card as a single pass. Wrapping each box
/// individually makes every placeholder pulse on its own clock, which reads as
/// noise rather than loading.
///
/// Prefer a skeleton that mirrors the real layout over a centred spinner: it
/// keeps the page from reflowing when data lands, and tells the user what is
/// about to appear.
///
/// ```dart
/// ModernSkeleton(
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: [
///       ModernSkeletonBox.text(width: 140),
///       SizedBox(height: AppDimensions.spacing8),
///       ModernSkeletonBox.text(width: 200, height: 28),
///     ],
///   ),
/// )
/// ```
class ModernSkeleton extends StatelessWidget {
  const ModernSkeleton({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// The skeleton layout to animate.
  final Widget child;

  /// When false the child renders as flat placeholders with no animation.
  /// Useful for golden tests, and to respect reduced-motion preferences.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// A single placeholder shape inside a [ModernSkeleton].
///
/// The colour is opaque rather than translucent because [Shimmer] paints its
/// gradient through the child's alpha - a semi-transparent box would wash the
/// highlight out.
class ModernSkeletonBox extends StatelessWidget {
  const ModernSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  /// A placeholder sized like a line of text.
  const ModernSkeletonBox.text({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
  }) : shape = BoxShape.rectangle;

  /// A circular placeholder, for avatars and icon slots.
  const ModernSkeletonBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : borderRadius ??
                BorderRadius.circular(AppDimensions.radiusSmall),
      ),
    );
  }
}
