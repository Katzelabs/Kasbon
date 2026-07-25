import 'package:flutter/material.dart';

/// Application gradient definitions for modern card designs
class AppGradients {
  AppGradients._();

  // Primary gradient (blue to purple) for summary cards
  static const LinearGradient primaryCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
  );

  // Secondary gradient (navy blue)
  static const LinearGradient secondaryCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF3B5998)],
  );

  // Success gradient for positive stats
  static const LinearGradient successCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  // Warning gradient for alerts
  static const LinearGradient warningCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  // Error gradient for critical alerts
  static const LinearGradient errorCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );

  // Info gradient for informational cards
  static const LinearGradient infoCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
  );

  // Neutral gradient for subtle cards
  static const LinearGradient neutralCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
  );
}
