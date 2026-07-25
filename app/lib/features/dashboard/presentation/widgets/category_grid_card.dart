import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// A category card for the home screen menu grid
///
/// Displays an icon and label for navigation to different features.
/// Used in the "Menu Kategori" section of the dashboard.
class CategoryGridCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const CategoryGridCard({
    super.key,
    required this.label,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.onTap,
  });

  /// Creates a category card with primary color accent
  factory CategoryGridCard.primary({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return CategoryGridCard(
      label: label,
      icon: icon,
      backgroundColor: AppColors.primaryContainer,
      iconColor: AppColors.primary,
      onTap: onTap,
    );
  }

  /// Creates a category card with secondary color accent
  factory CategoryGridCard.secondary({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return CategoryGridCard(
      label: label,
      icon: icon,
      backgroundColor: AppColors.secondaryContainer,
      iconColor: AppColors.secondary,
      onTap: onTap,
    );
  }

  /// Creates a category card with success color accent
  factory CategoryGridCard.success({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return CategoryGridCard(
      label: label,
      icon: icon,
      backgroundColor: AppColors.successLight,
      iconColor: AppColors.success,
      onTap: onTap,
    );
  }

  /// Creates a category card with warning color accent
  factory CategoryGridCard.warning({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return CategoryGridCard(
      label: label,
      icon: icon,
      backgroundColor: AppColors.warningLight,
      iconColor: AppColors.warning,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.surface;
    final icColor = iconColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        splashColor: icColor.withValues(alpha: 0.1),
        highlightColor: icColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: icColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container with gradient background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      bgColor,
                      bgColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: icColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: icColor,
                  size: AppDimensions.iconLarge,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              // Label
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Chevron indicator
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: AppDimensions.iconMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu category item data model
class MenuCategory {
  final String label;
  final IconData icon;
  final String routePath;
  final Color? backgroundColor;
  final Color? iconColor;

  const MenuCategory({
    required this.label,
    required this.icon,
    required this.routePath,
    this.backgroundColor,
    this.iconColor,
  });
}

/// Default menu categories for the KASBON POS app
/// Matches sidebar navigation items (excluding Beranda)
class DefaultMenuCategories {
  DefaultMenuCategories._();

  static const List<MenuCategory> items = [
    MenuCategory(
      label: 'Kasir',
      icon: Icons.point_of_sale,
      routePath: '/pos',
      backgroundColor: Color(0xFFDBEAFE),
      iconColor: Color(0xFF2563EB),
    ),
    MenuCategory(
      label: 'Produk',
      icon: Icons.inventory_2,
      routePath: '/products',
      backgroundColor: Color(0xFFDCFCE7),
      iconColor: Color(0xFF10B981),
    ),
    MenuCategory(
      label: 'Transaksi',
      icon: Icons.receipt_long,
      routePath: '/transactions',
      backgroundColor: Color(0xFFFEF3C7),
      iconColor: Color(0xFFF59E0B),
    ),
    MenuCategory(
      label: 'Hutang',
      icon: Icons.credit_card_off,
      routePath: '/debts',
      backgroundColor: Color(0xFFFEE2E2),
      iconColor: Color(0xFFEF4444),
    ),
    MenuCategory(
      label: 'Laporan',
      icon: Icons.bar_chart,
      routePath: '/reports',
      backgroundColor: Color(0xFFCFFAFE),
      iconColor: Color(0xFF06B6D4),
    ),
    MenuCategory(
      label: 'Pengaturan',
      icon: Icons.settings,
      routePath: '/settings',
      backgroundColor: Color(0xFFF3F4F6),
      iconColor: Color(0xFF6B7280),
    ),
    // Dev Tools (for development only)
    MenuCategory(
      label: 'Dev Tools',
      icon: Icons.developer_mode,
      routePath: '/dev',
      backgroundColor: Color(0xFFFCE7F3),
      iconColor: Color(0xFFEC4899),
    ),
  ];
}
