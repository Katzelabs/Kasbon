import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../button/modern_button.dart';

/// A Modern-styled empty state display
///
/// Example:
/// ```dart
/// ModernEmptyState.list(
///   title: 'Belum Ada Produk',
///   message: 'Tambahkan produk pertama Anda',
///   actionLabel: 'Tambah Produk',
///   onAction: () => context.push('/products/add'),
/// )
/// ```
class ModernEmptyState extends StatelessWidget {
  const ModernEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.title,
    this.actionLabel,
    this.onAction,
    this.imageAsset,
  });

  /// Creates an empty state for empty lists
  factory ModernEmptyState.list({
    Key? key,
    String? title,
    String message = 'Belum ada data',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ModernEmptyState(
      key: key,
      title: title,
      message: message,
      icon: Icons.inbox_outlined,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Creates an empty state for search results
  factory ModernEmptyState.search({
    Key? key,
    String message = 'Tidak ada hasil ditemukan',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ModernEmptyState(
      key: key,
      title: 'Tidak Ditemukan',
      message: message,
      icon: Icons.search_off_outlined,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Creates an empty state for empty cart
  factory ModernEmptyState.cart({
    Key? key,
    String message = 'Keranjang belanja kosong',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ModernEmptyState(
      key: key,
      title: 'Keranjang Kosong',
      message: message,
      icon: Icons.shopping_cart_outlined,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  final String message;
  final IconData? icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset!,
                width: 120,
                height: 120,
              )
            else if (icon != null)
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: AppColors.textTertiary,
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDimensions.spacing24),
              ModernButton.primary(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
