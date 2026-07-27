import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';

import 'responsive_helpers.dart';

/// Tests for the test harness itself.
///
/// Without these, a `pumpAtWidth` that silently failed to resize would make
/// every responsive test in the suite pass vacuously at the default 800x600 -
/// green, and worthless. These assert the harness does the one thing the rest
/// of the responsive work depends on it doing.
void main() {
  group('pumpAtWidth', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets('MediaQuery reports ${ResponsiveWidths.label(width)}',
          (tester) async {
        late double observed;

        await pumpAtWidth(
          tester,
          width,
          Builder(builder: (context) {
            observed = MediaQuery.of(context).size.width;
            return const SizedBox.shrink();
          }),
        );

        expect(observed, width);
      });
    }

    testWidgets('the view is restored after a test that resized it',
        (tester) async {
      // Runs after the loop above, which set the view to 1600. If the
      // addTearDown restore is broken, this leaks in as 1600.
      expect(tester.view.physicalSize, tester.view.display.size);
    });
  });

  group('tier classification at each harness width', () {
    // Pins the harness widths to the tiers they are meant to represent. If a
    // breakpoint constant moves, this fails loudly here rather than quietly
    // reclassifying every responsive test in the suite.
    late Breakpoint observed;

    Future<void> pumpAndClassify(WidgetTester tester, double width) {
      return pumpAtWidth(
        tester,
        width,
        Builder(builder: (context) {
          observed = context.breakpoint;
          return const SizedBox.shrink();
        }),
      );
    }

    testWidgets('375 is compact', (tester) async {
      await pumpAndClassify(tester, ResponsiveWidths.compact);
      expect(observed, Breakpoint.compact);
    });

    testWidgets('700 is medium', (tester) async {
      // The band the epic exists for. Under the legacy three-tier getters this
      // width reports "mobile", because breakpointMobile is 900 - so a small
      // tablet gets the phone build. The four-tier API can finally name it.
      await pumpAndClassify(tester, ResponsiveWidths.medium);
      expect(observed, Breakpoint.medium);
    });

    testWidgets('1100 is expanded', (tester) async {
      await pumpAndClassify(tester, ResponsiveWidths.expanded);
      expect(observed, Breakpoint.expanded);
    });

    testWidgets('1600 is large', (tester) async {
      await pumpAndClassify(tester, ResponsiveWidths.large);
      expect(observed, Breakpoint.large);
    });
  });

  group('setViewWidth', () {
    testWidgets('supports resizing mid-test, as a window drag would',
        (tester) async {
      late double observed;

      final probe = Builder(builder: (context) {
        observed = MediaQuery.of(context).size.width;
        return const SizedBox.shrink();
      });

      await pumpAtWidth(tester, ResponsiveWidths.large, probe);
      expect(observed, ResponsiveWidths.large);

      setViewWidth(tester, ResponsiveWidths.compact);
      await tester.pump();

      expect(observed, ResponsiveWidths.compact);
    });
  });
}
