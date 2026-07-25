/// Shared variant enums for Modern widget library
library;

/// Universal size variants for Modern components
enum ModernSize {
  small,
  medium,
  large;

  /// Returns true if this is the small size
  bool get isSmall => this == ModernSize.small;

  /// Returns true if this is the medium size
  bool get isMedium => this == ModernSize.medium;

  /// Returns true if this is the large size
  bool get isLarge => this == ModernSize.large;
}

/// Button style variants
enum ModernButtonVariant {
  /// Filled button with primary color background
  primary,

  /// Filled button with secondary/lighter background
  secondary,

  /// Bordered button with transparent background
  outline,

  /// Text-only button with no background or border
  text,

  /// Destructive/danger button for delete actions
  destructive;

  /// Returns true if this variant has a filled background
  bool get isFilled =>
      this == ModernButtonVariant.primary ||
      this == ModernButtonVariant.secondary ||
      this == ModernButtonVariant.destructive;

  /// Returns true if this is a destructive action
  bool get isDestructive => this == ModernButtonVariant.destructive;
}

/// Card style variants
enum ModernCardVariant {
  /// Card with shadow/elevation
  elevated,

  /// Card with border, no shadow
  outlined,

  /// Card with filled background, no border
  filled;

  /// Returns true if this variant has elevation
  bool get hasElevation => this == ModernCardVariant.elevated;

  /// Returns true if this variant has a border
  bool get hasBorder => this == ModernCardVariant.outlined;
}

/// Input field variants
enum ModernInputVariant {
  /// Input with border all around
  outline,

  /// Input with filled background
  filled,

  /// Input with bottom border only
  underline;
}

/// Badge/status variants
enum ModernBadgeVariant {
  /// Success/positive status (green)
  success,

  /// Warning status (amber/orange)
  warning,

  /// Error/danger status (red)
  error,

  /// Informational status (blue)
  info,

  /// Neutral/default status (gray)
  neutral;
}

/// Toast notification variants
enum ModernToastVariant {
  /// Success notification (green)
  success,

  /// Error notification (red)
  error,

  /// Warning notification (amber)
  warning,

  /// Info notification (blue)
  info;
}

/// AppBar style variants
enum ModernAppBarVariant {
  /// Standard elevated app bar with shadow
  elevated,

  /// Flat app bar with no shadow
  flat,

  /// Transparent app bar
  transparent,

  /// Colored app bar with primary background
  primary;
}
