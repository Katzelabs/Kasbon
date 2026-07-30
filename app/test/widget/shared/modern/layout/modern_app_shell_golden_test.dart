import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/theme/app_colors.dart';
import 'package:kasbon_pos/shared/modern/components/layout/modern_app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/responsive_helpers.dart';

/// Pixel baselines for the shell's chrome at each tier.
///
/// ## What these add over the behavioural tests
///
/// `modern_app_shell_test.dart` already pins the tier → chrome *contract* in 15
/// tests: which nav appears, how wide the rail is, whether the toggle exists,
/// where each destination goes. It cannot see any of the things that make the
/// chrome look right - the hairline between rail and content, the logo tile's
/// alignment against the first destination, the active row's fill geometry, the
/// gap the footer leaves at the bottom, or the notch the compact FAB cuts. Every
/// one of those has been adjusted by hand during RESP_04-09b and after (see
/// `d67dd1c` for the header hairline and `52f7607` for the card border that was
/// painting over its own content), and none of them has a test.
///
/// So these are deliberately whole-chrome captures rather than per-component
/// ones. A golden that framed just the rail would miss the thing most likely to
/// go wrong, which is the rail's relationship to what sits beside it.
///
/// ## Reading a failure
///
/// A diff is a report, not a verdict - the chrome is still being designed, and an
/// intentional change lands here as a failure first. Look at the three images
/// flutter_test writes next to the golden (`*_masterImage`, `*_testImage`,
/// `*_maskedDiff`); if the new rendering is the intended one, re-record with:
///
/// ```sh
/// flutter test --update-goldens test/widget/shared/modern/layout/
/// ```
///
/// and commit the PNGs with the change that caused them.
///
/// ## Two things these are not
///
/// **Not typography.** `flutter test` renders text in a blank placeholder font,
/// so every label here is a run of filled boxes. That is a feature for this
/// purpose - the boxes still occupy the real metrics, so a label that outgrows
/// its row still shows up, while a font-hinting difference between two machines
/// does not.
///
/// **Not portable across hosts.** These were recorded on macOS. Flutter's own
/// guidance is that goldens are only comparable on the platform that wrote them,
/// so a Linux CI job should skip this file rather than fail it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No stored sidebar preference, so each tier shows its own default: the
    // rail starts collapsed at `expanded` and expanded at `large`. Those
    // defaults are half of what these images are for.
    SharedPreferences.setMockInitialValues({});
  });

  /// The shell with a flat, deterministic body.
  ///
  /// The body is a plain fill rather than a realistic screen for two reasons:
  /// a real screen would drag its own providers and its own churn into every
  /// one of these images, and a flat colour is what makes the chrome legible -
  /// the content edge, the 80dp or 280dp the rail takes, and the strip the
  /// compact bottom bar floats over are all visible as boundaries against it.
  ///
  /// `SizedBox.expand` is load-bearing. A bare `ColoredBox` sizes to its child,
  /// so with none it collapses to nothing under the body's loose constraints and
  /// every image comes back showing the scaffold's own `#FEF7FF` - identical to
  /// having passed no body at all, and silently so.
  Widget shellAt(String currentPath) => ModernAppShell(
        currentPath: currentPath,
        // Captured rather than routed: `context.go` needs a router above the
        // shell, and none of these images are about routing.
        onNavigate: (_) {},
        onFabPressed: () {},
        child: const SizedBox.expand(
          child: ColoredBox(color: AppColors.surfaceVariant),
        ),
      );

  /// Height chosen per tier rather than shared.
  ///
  /// A single tall viewport would leave the compact image mostly empty and crop
  /// the large one's rail footer. These are roughly the aspect ratio each tier
  /// is actually used at: a phone is tall, a desktop window is wide.
  ///
  /// A switch rather than a map because a `const` map keyed on doubles is not
  /// allowed - doubles have no primitive equality - and a non-const one here
  /// would just be a lookup table pretending to be data.
  double heightFor(double width) => switch (width) {
        ResponsiveWidths.compact => 812, // iPhone-ish portrait
        ResponsiveWidths.medium => 1000, // iPad portrait, half-height window
        ResponsiveWidths.expanded => 800, // landscape tablet
        _ => 900, // desktop window
      };

  for (final width in ResponsiveWidths.all) {
    final label = ResponsiveWidths.label(width).split('(').first;

    testWidgets('$label chrome', (tester) async {
      await pumpScreenAtWidth(
        tester,
        width,
        shellAt('/dashboard'),
        height: heightFor(width),
      );

      await expectLater(
        find.byType(ModernAppShell),
        matchesGoldenFile('goldens/shell_$label.png'),
      );
    });
  }

  testWidgets('expanded chrome with the rail widened', (tester) async {
    // The fifth image, and the only one showing a state a user has to ask for.
    // `expanded` is the tier where both rail widths are reachable - 900-1299dp
    // has room for 280dp but not enough to spend it by default - so this is
    // where an alignment bug in the labelled rail would first appear.
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.expanded,
      shellAt('/dashboard'),
      height: heightFor(ResponsiveWidths.expanded),
    );

    await tester.tap(find.byTooltip('Lebarkan menu'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ModernAppShell),
      matchesGoldenFile('goldens/shell_expanded_rail_open.png'),
    );
  });
}
