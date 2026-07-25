import 'package:flutter/material.dart';

/// Application color palette based on KASBON branding
class AppColors {
  AppColors._();

  // Primary Colors (Blue - Trust, Professional for POS)
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFF1E40AF);

  // Interactive States
  static const Color primaryHover = Color(0xFF3B82F6);
  static const Color primaryPressed = Color(0xFF1D4ED8);
  static const Color primaryDisabled = Color(0xFFBFDBFE);

  // Secondary Colors (Navy Blue - Professional)
  static const Color secondary = Color(0xFF1E3A8A);
  static const Color secondaryLight = Color(0xFF3B5998);
  static const Color secondaryDark = Color(0xFF152A63);
  static const Color secondaryContainer = Color(0xFFD6E0F5);
  static const Color onSecondary = Colors.white;

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Neutral Colors
  //
  // The canvas carries a slight cool cast rather than pure neutral grey. Set
  // against white cards it reads as clean daylight instead of the muddy,
  // washed-out look flat #F5F5F5 gives.
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEFF2F6);
  static const Color card = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnSecondary = Colors.white;

  // Border Colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFE5E7EB);

  // Shadow Color
  //
  // Prefer the semantic ramp in `AppShadows` for any BoxShadow. This single
  // colour remains only for Material APIs that take a `shadowColor` and build
  // the geometry themselves.
  static const Color shadow = Color(0x140F172A);

  // Shimmer Colors (cool-cast to sit correctly on the new canvas)
  static const Color shimmerBase = Color(0xFFE6EAF0);
  static const Color shimmerHighlight = Color(0xFFF7F9FC);

  // Surface Variants
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color overlay = Color(0x80000000);

  // Extended Accents
  //
  // The status colours above cover most tinted-surface needs (a saturated
  // foreground paired with its `*Light` wash). These two fill the gaps for
  // category tiles that must stay visually distinct from any status meaning.
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentCyanLight = Color(0xFFCFFAFE);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentPinkLight = Color(0xFFFCE7F3);

  // Rank Medals (leaderboard positions in reports)
  static const Color rankGold = Color(0xFFD4A017);
  static const Color rankSilver = Color(0xFF9CA3AF);
  static const Color rankBronze = Color(0xFFB87333);

  /// Medal colour for a leaderboard position.
  ///
  /// Three report widgets each defined their own version of this, and two of
  /// them disagreed with the third about what gold and silver were. Anything
  /// past third place falls back to a neutral so the podium stays distinct.
  static Color rankColor(int rank) => switch (rank) {
        1 => rankGold,
        2 => rankSilver,
        3 => rankBronze,
        _ => textTertiary,
      };

  // Brand Colors (third-party services)
  static const Color whatsapp = Color(0xFF25D366);

  // Category Colors (for product categories)
  static const List<Color> categoryColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF6B7280), // Grey (default)
  ];
}
