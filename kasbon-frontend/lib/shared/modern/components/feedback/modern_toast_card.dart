import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';
import 'modern_toast_controller.dart';

/// Single animated toast card rendered inside [ToastController]'s overlay.
///
/// Not exported from the feedback barrel — only used by [ToastController].
class ToastCard extends StatefulWidget {
  const ToastCard({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

  final ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  State<ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoDismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _autoDismissTimer = Timer(widget.entry.duration, _handleClose);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.entry.variant;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Semantics(
          liveRegion: true,
          label: widget.entry.message,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: _backgroundColor(variant),
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing16,
                vertical: AppDimensions.spacing12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icon(variant),
                    color: Colors.white,
                    size: AppDimensions.iconLarge,
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Flexible(
                    child: Text(
                      widget.entry.message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  InkWell(
                    onTap: _handleClose,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(AppDimensions.spacing4),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: AppDimensions.iconMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _backgroundColor(ModernToastVariant variant) {
    switch (variant) {
      case ModernToastVariant.success:
        return AppColors.success;
      case ModernToastVariant.error:
        return AppColors.error;
      case ModernToastVariant.warning:
        return AppColors.warning;
      case ModernToastVariant.info:
        return AppColors.info;
    }
  }

  static IconData _icon(ModernToastVariant variant) {
    switch (variant) {
      case ModernToastVariant.success:
        return Icons.check_circle_outline;
      case ModernToastVariant.error:
        return Icons.error_outline;
      case ModernToastVariant.warning:
        return Icons.warning_amber_outlined;
      case ModernToastVariant.info:
        return Icons.info_outline;
    }
  }
}
