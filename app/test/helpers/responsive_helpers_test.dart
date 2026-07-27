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
    late DeviceType observed;

    Future<void> pumpAndClassify(WidgetTester tester, double width) {
      return pumpAtWidth(
        tester,
        width,
        Builder(builder: (context) {
          observed = ResponsiveUtils.getDeviceType(context);
          return const SizedBox.shrink();
        }),
      );
    }

    testWidgets('375 is mobile', (tester) async {
      await pumpAndClassify(tester, ResponsiveWidths.compact);
      expect(observed, DeviceType.mobile);
    });

    testWidgets('700 is mobile today (becomes its own tier in RESP_03)',
        (tester) async {
      // Documents the bug the overhaul exists to fix: 700dp - a small tablet -
      // currently gets the phone build, because breakpointMobile is 900.
      await pumpAndClassify(tester, ResponsiveWidths.medium);
      expect(observed, DeviceType.mobile);
    });

    testWidgets('1100 is tablet', (tester) async {
      await pumpAndClassify(tester, ResponsiveWidths.expanded);
      expect(observed, DeviceType.tablet);
    });

    testWidgets('1600 is desktop', (tester) async {
      await pumpAndClassify(tester, ResponsiveWidths.large);
      expect(observed, DeviceType.desktop);
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
