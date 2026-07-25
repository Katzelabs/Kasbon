import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Application typography styles
///
/// The app ships a single bundled family, Plus Jakarta Sans, in five weights
/// (400/500/600/700/800). Declaring it in `pubspec.yaml` matters: an
/// undeclared family name silently falls through to the platform default,
/// which is how prices previously ended up rendering in a proportional font
/// on every platform.
///
/// Prices do not use a separate monospace family. Instead they opt into the
/// font's `tnum` (tabular figures) feature, so every digit occupies the same
/// advance width and columns line up in carts, reports and receipts - without
/// the visual jolt of a second typeface mid-sentence.
class AppTextStyles {
  AppTextStyles._();

  // Font Family
  static const String fontFamily = 'PlusJakartaSans';

  /// Fixed-width digits. Apply to anything numeric that stacks vertically or
  /// updates in place (totals, quantities, report columns, countdown values)
  /// so the text does not jitter as digits change.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  // Headings
  //
  // Plus Jakarta Sans is a geometric sans with a large x-height, so display
  // sizes need negative tracking to avoid looking loose. Sizes are unchanged
  // from the previous scale to keep existing layouts intact; the weight and
  // tracking are what carry the new voice.
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.4,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.35,
    letterSpacing: -0.2,
  );

  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 0.2,
  );

  // Numbers (prices, totals - tabular figures for column alignment)
  static const TextStyle priceLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.4,
    fontFeatures: tabularFigures,
  );

  static const TextStyle priceMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.2,
    fontFeatures: tabularFigures,
  );

  static const TextStyle priceSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
    fontFeatures: tabularFigures,
  );

  // Button Text
  //
  // Geometric sans faces do not need the extra tracking Roboto wanted at
  // button sizes; 0.5 read as spaced-out lettering rather than emphasis.
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: Colors.white,
    height: 1.25,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: Colors.white,
    height: 1.25,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: AppColors.textTertiary,
    height: 1.4,
  );
}
