import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/brand/kasbon_mark.dart';

/// KASBON's mark and wordmark, above an auth form.
///
/// The logo was a bare `Icon(size: 64)` in flat primary - the shape of a logo
/// without the weight of one. A gradient tile with a matching glow reads as a
/// brand mark at the same footprint, and it is the only place in the app where
/// the product introduces itself, so it is worth the pixels.
///
/// The tile is [KasbonLogoTile], the same drawing `brand/generate.py` bakes
/// into the app icons, so the first thing a new user sees here is the icon
/// they just tapped. It used to be `Icons.point_of_sale_rounded` - a stock
/// Material glyph standing in for a mark the product did not yet have.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key}) : compact = false;

  /// Mark and wordmark only, at a smaller size and without the tagline.
  ///
  /// Register has five fields and a strength meter under them; spending the
  /// full header on a phone pushes the first field below the fold, and a form
  /// whose first field you have to scroll to find looks broken.
  const AuthBrandHeader.compact({super.key}) : compact = true;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tileSize = compact ? 56.0 : 72.0;

    return Column(
      children: [
        KasbonLogoTile(size: tileSize),
        SizedBox(
          height: compact ? AppDimensions.spacing12 : AppDimensions.spacing16,
        ),
        Text(
          'KASBON',
          style: (compact ? AppTextStyles.h2 : AppTextStyles.h1).copyWith(
            color: AppColors.primary,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
        if (!compact) ...[
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            'Kasir Bisnis Online',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// The `Masuk ke Akun Anda` / `Buat Akun Baru` pair above the fields.
///
/// Split out so the two screens cannot drift on spacing or on which style the
/// title takes, which is exactly what happened before: login used `h3`,
/// register used `h2`, and the gap beneath them differed by 8dp.
class AuthFormTitle extends StatelessWidget {
  const AuthFormTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
