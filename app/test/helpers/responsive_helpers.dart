import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// The four widths every responsive test should cover.
///
/// These are the tier representatives used throughout the responsive overhaul:
/// a phone, a small tablet / half-screen window, a landscape tablet, and a
/// desktop window. They are deliberately *inside* each band rather than on a
/// boundary, so a one-pixel change to a breakpoint constant doesn't silently
/// reclassify a test.
class ResponsiveWidths {
  ResponsiveWidths._();

  /// Phone portrait.
  static const double compact = 375;

  /// Small tablet portrait / half-screen window.
  static const double medium = 700;

  /// Landscape tablet — today's `isTablet`.
  static const double expanded = 1100;

  /// Desktop window — today's `isDesktop`.
  static const double large = 1600;

  /// All four, in ascending order. Use with a `for` loop to run one body at
  /// every tier.
  static const List<double> all = [compact, medium, expanded, large];

  /// Human-readable label, for test names and failure messages.
  static String label(double width) => switch (width) {
        compact => 'compact($compact)',
        medium => 'medium($medium)',
        expanded => 'expanded($expanded)',
        large => 'large($large)',
        _ => '${width}dp',
      };
}

/// Pumps [widget] with the test view resized to [width].
///
/// Sets `tester.view.physicalSize` rather than wrapping in a `MediaQuery`,
/// because the two are not equivalent for this codebase: a `MediaQuery`
/// override is invisible to anything reading the view directly, and it does
/// not survive the root `MediaQuery` that `MaterialApp` installs. Resizing the
/// view is what a real window resize does.
///
/// The size is reset via `addTearDown`, so tests that run after this one see a
/// clean view even if this one fails partway through.
///
/// [height] defaults to a tall-ish portrait value so vertical overflow doesn't
/// masquerade as a horizontal layout failure. Pass it explicitly when testing
/// something height-sensitive.
///
/// Example:
/// ```dart
/// for (final width in ResponsiveWidths.all) {
///   testWidgets('renders at ${ResponsiveWidths.label(width)}', (tester) async {
///     await pumpAtWidth(tester, width, const MyWidget());
///     expect(find.byType(MyWidget), findsOneWidget);
///   });
/// }
/// ```
Future<void> pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget widget, {
  double height = 1200,
  List<Override>? providerOverrides,
  bool settle = true,
}) async {
  setViewWidth(tester, width, height: height);

  await tester.pumpWidget(createTestableWidget(
    child: widget,
    providerOverrides: providerOverrides,
  ));

  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// As [pumpAtWidth], but without the `Scaffold` wrapper — for widgets that
/// provide their own (screens, anything using `ModernAppBar`).
Future<void> pumpScreenAtWidth(
  WidgetTester tester,
  double width,
  Widget widget, {
  double height = 1200,
  List<Override>? providerOverrides,
  bool settle = true,
}) async {
  setViewWidth(tester, width, height: height);

  await tester.pumpWidget(createTestableWidgetWithoutScaffold(
    child: widget,
    providerOverrides: providerOverrides,
  ));

  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// Resizes the test view to [width] x [height] in logical pixels, registering
/// a tear-down that restores it.
///
/// Exposed separately for tests that need to resize *mid-test* — e.g. asserting
/// that a layout survives a window drag across a breakpoint. Call it, then
/// `await tester.pump()`.
void setViewWidth(
  WidgetTester tester,
  double width, {
  double height = 1200,
}) {
  final view = tester.view;

  // physicalSize is in device pixels; dividing the logical size we want by the
  // ratio keeps `MediaQuery.size` equal to `width` regardless of the ratio the
  // test view happens to carry.
  view.devicePixelRatio = 1.0;
  view.physicalSize = Size(width, height);

  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}
