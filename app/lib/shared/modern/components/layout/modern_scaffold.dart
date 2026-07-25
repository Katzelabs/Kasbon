import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../feedback/modern_loading.dart';

/// A Modern-styled scaffold with consistent defaults and built-in features
///
/// Features:
/// - Consistent background color from theme
/// - Built-in safe area handling
/// - Optional loading overlay
/// - Optional padding wrapper
///
/// Example:
/// ```dart
/// ModernScaffold(
///   appBar: ModernAppBar.back(title: 'Produk'),
///   body: YourContent(),
///   isLoading: isSubmitting,
/// )
/// ```
class ModernScaffold extends StatelessWidget {
  const ModernScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.padding,
    this.safeArea = true,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.isLoading = false,
    this.loadingMessage,
  });

  /// The primary content of the scaffold
  final Widget body;

  /// An app bar to display at the top of the scaffold
  final PreferredSizeWidget? appBar;

  /// A bottom navigation bar to display at the bottom of the scaffold
  final Widget? bottomNavigationBar;

  /// A floating action button to display
  final Widget? floatingActionButton;

  /// The location of the floating action button
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// A drawer to display on the left side
  final Widget? drawer;

  /// A drawer to display on the right side
  final Widget? endDrawer;

  /// The background color of the scaffold
  /// Defaults to [AppColors.background]
  final Color? backgroundColor;

  /// Optional padding to wrap the body content
  final EdgeInsets? padding;

  /// Whether to wrap the body in a SafeArea widget
  final bool safeArea;

  /// Whether to include the top padding in safe area
  final bool safeAreaTop;

  /// Whether to include the bottom padding in safe area
  final bool safeAreaBottom;

  /// Whether to include the left padding in safe area
  final bool safeAreaLeft;

  /// Whether to include the right padding in safe area
  final bool safeAreaRight;

  /// Whether the body should resize when the keyboard appears
  final bool resizeToAvoidBottomInset;

  /// Whether the body extends behind the bottom navigation bar
  final bool extendBody;

  /// Whether the body extends behind the app bar
  final bool extendBodyBehindAppBar;

  /// Whether to show a loading overlay
  final bool isLoading;

  /// Optional message to display with the loading overlay
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    // Apply padding if specified
    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    // Apply safe area if enabled
    if (safeArea) {
      content = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        left: safeAreaLeft,
        right: safeAreaRight,
        child: content,
      );
    }

    final scaffold = Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor ?? AppColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );

    // Show loading overlay if loading
    if (isLoading) {
      return Stack(
        children: [
          scaffold,
          ModernLoading.overlay(message: loadingMessage),
        ],
      );
    }

    return scaffold;
  }
}

/// Extension methods for ModernScaffold
extension ModernScaffoldExtension on ModernScaffold {
  /// Creates a scaffold with default page padding
  static ModernScaffold withPadding({
    Key? key,
    required Widget body,
    PreferredSizeWidget? appBar,
    Widget? bottomNavigationBar,
    Widget? floatingActionButton,
    FloatingActionButtonLocation? floatingActionButtonLocation,
    Color? backgroundColor,
    bool safeArea = true,
    bool isLoading = false,
    String? loadingMessage,
  }) {
    return ModernScaffold(
      key: key,
      body: body,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      safeArea: safeArea,
      isLoading: isLoading,
      loadingMessage: loadingMessage,
    );
  }
}
