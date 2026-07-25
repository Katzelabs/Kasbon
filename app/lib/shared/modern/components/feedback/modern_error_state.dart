import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../button/modern_button.dart';

/// A Modern-styled error state with retry action
///
/// Example:
/// ```dart
/// ModernErrorState.network(
///   onRetry: () => ref.invalidate(productsProvider),
/// )
/// ```
class ModernErrorState extends StatelessWidget {
  const ModernErrorState({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Coba Lagi',
  });

  /// Creates a generic error state
  factory ModernErrorState.generic({
    Key? key,
    String message = 'Terjadi kesalahan. Silakan coba lagi.',
    VoidCallback? onRetry,
  }) {
    return ModernErrorState(
      key: key,
      title: 'Terjadi Kesalahan',
      message: message,
      icon: Icons.error_outline,
      onRetry: onRetry,
    );
  }

  /// Creates a network error state
  factory ModernErrorState.network({
    Key? key,
    String message = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
    VoidCallback? onRetry,
  }) {
    return ModernErrorState(
      key: key,
      title: 'Koneksi Gagal',
      message: message,
      icon: Icons.wifi_off_outlined,
      onRetry: onRetry,
    );
  }

  /// Creates a not found error state
  factory ModernErrorState.notFound({
    Key? key,
    String message = 'Data yang Anda cari tidak ditemukan.',
    VoidCallback? onRetry,
  }) {
    return ModernErrorState(
      key: key,
      title: 'Tidak Ditemukan',
      message: message,
      icon: Icons.search_off_outlined,
      onRetry: onRetry,
    );
  }

  final String message;
  final String? title;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
            const SizedBox(height: AppDimensions.spacing16),
            if (title != null) ...[
              Text(
                title!,
                style: AppTextStyles.h4,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacing8),
            ],
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spacing24),
              ModernButton.primary(
                leadingIcon: Icons.refresh,
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
