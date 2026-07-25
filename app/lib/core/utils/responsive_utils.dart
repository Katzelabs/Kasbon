import 'package:flutter/material.dart';

import '../../config/theme/app_dimensions.dart';

/// Device type classification based on screen width
enum DeviceType { mobile, tablet, desktop }

/// Utility class for responsive design breakpoint detection
class ResponsiveUtils {
  ResponsiveUtils._();

  /// Get the device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppDimensions.breakpointMobile) return DeviceType.mobile;
    if (width < AppDimensions.breakpointDesktop) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Check if current device is mobile (< 600dp)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppDimensions.breakpointMobile;

  /// Check if current device is tablet (>= 600dp and < 1200dp)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppDimensions.breakpointMobile &&
        width < AppDimensions.breakpointDesktop;
  }

  /// Check if current device is desktop (>= 1200dp)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppDimensions.breakpointDesktop;

  /// Check if current device is tablet or desktop (>= 600dp)
  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppDimensions.breakpointMobile;

  /// Get the number of grid columns based on device type
  static int getGridColumns(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// Get horizontal padding based on device type
  static double getHorizontalPadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return AppDimensions.spacing16;
      case DeviceType.tablet:
        return AppDimensions.spacing24;
      case DeviceType.desktop:
        return AppDimensions.spacing32;
    }
  }
}

/// Extension on BuildContext for easier responsive checks
extension ResponsiveContext on BuildContext {
  /// Check if current device is mobile
  bool get isMobile => ResponsiveUtils.isMobile(this);

  /// Check if current device is tablet
  bool get isTablet => ResponsiveUtils.isTablet(this);

  /// Check if current device is desktop
  bool get isDesktop => ResponsiveUtils.isDesktop(this);

  /// Check if current device is tablet or desktop
  bool get isTabletOrDesktop => ResponsiveUtils.isTabletOrDesktop(this);

  /// Get the current device type
  DeviceType get deviceType => ResponsiveUtils.getDeviceType(this);

  /// Get responsive grid columns
  int gridColumns({int mobile = 2, int tablet = 3, int desktop = 4}) =>
      ResponsiveUtils.getGridColumns(this, mobile: mobile, tablet: tablet, desktop: desktop);

  /// Get responsive horizontal padding
  double get horizontalPadding => ResponsiveUtils.getHorizontalPadding(this);
}
