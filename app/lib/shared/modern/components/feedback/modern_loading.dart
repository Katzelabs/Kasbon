import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled loading indicator with consistent theming
///
/// Example:
/// ```dart
/// ModernLoading()
/// ModernLoading.small()
/// ModernLoading.large(color: AppColors.primary)
/// ModernLoading.overlay(message: 'Memuat...')
/// ```
class ModernLoading extends StatelessWidget {
  const ModernLoading({
    super.key,
    this.size = ModernSize.medium,
    this.color,
    this.strokeWidth,
  });

  /// Creates a small loading indicator
  const ModernLoading.small({
    super.key,
    this.color,
  })  : size = ModernSize.small,
        strokeWidth = 2.0;

  /// Creates a medium loading indicator
  const ModernLoading.medium({
    super.key,
    this.color,
  })  : size = ModernSize.medium,
        strokeWidth = 3.0;

  /// Creates a large loading indicator
  const ModernLoading.large({
    super.key,
    this.color,
  })  : size = ModernSize.large,
        strokeWidth = 4.0;

  /// Creates a full-screen loading overlay
  static Widget overlay({
    Key? key,
    String? message,
    Color? backgroundColor,
    Color? spinnerColor,
  }) {
    return _ModernLoadingOverlay(
      key: key,
      message: message,
      backgroundColor: backgroundColor,
      spinnerColor: spinnerColor,
    );
  }

  /// Creates a centered loading indicator
  static Widget center({
    Key? key,
    ModernSize size = ModernSize.medium,
    Color? color,
  }) {
    return Center(
      key: key,
      child: ModernLoading(size: size, color: color),
    );
  }

  /// The size of the loading indicator
  final ModernSize size;

  /// The color of the loading indicator
  final Color? color;

  /// The stroke width of the circular indicator
  final double? strokeWidth;

  double get _dimension {
    switch (size) {
      case ModernSize.small:
        return 16;
      case ModernSize.medium:
        return 24;
      case ModernSize.large:
        return 40;
    }
  }

  double get _strokeWidth {
    if (strokeWidth != null) return strokeWidth!;
    switch (size) {
      case ModernSize.small:
        return 2.0;
      case ModernSize.medium:
        return 3.0;
      case ModernSize.large:
        return 4.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _dimension,
      height: _dimension,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary,
        ),
      ),
    );
  }
}

/// Full-screen loading overlay widget
class _ModernLoadingOverlay extends StatelessWidget {
  const _ModernLoadingOverlay({
    super.key,
    this.message,
    this.backgroundColor,
    this.spinnerColor,
  });

  final String? message;
  final Color? backgroundColor;
  final Color? spinnerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? AppColors.overlay,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoading.large(color: spinnerColor ?? AppColors.onPrimary),
            if (message != null) ...[
              const SizedBox(height: AppDimensions.spacing16),
              Text(
                message!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: spinnerColor ?? AppColors.onPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmer loading placeholder for skeleton screens
class ModernShimmer extends StatelessWidget {
  const ModernShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// Creates a rectangular shimmer box
  factory ModernShimmer.box({
    Key? key,
    double? width,
    double height = 16,
    double borderRadius = AppDimensions.radiusSmall,
    bool enabled = true,
  }) {
    return ModernShimmer(
      key: key,
      enabled: enabled,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Creates a circular shimmer
  factory ModernShimmer.circle({
    Key? key,
    double diameter = 40,
    bool enabled = true,
  }) {
    return ModernShimmer(
      key: key,
      enabled: enabled,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: const BoxDecoration(
          color: AppColors.shimmerBase,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// The child widget to apply shimmer effect to
  final Widget child;

  /// Whether the shimmer effect is enabled
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return _ShimmerEffect(child: child);
  }
}

/// Internal shimmer animation effect
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect({required this.child});

  final Widget child;

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                AppColors.shimmerBase,
                AppColors.shimmerHighlight,
                AppColors.shimmerBase,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
