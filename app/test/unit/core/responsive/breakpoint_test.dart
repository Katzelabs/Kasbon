import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/responsive/breakpoint.dart';

void main() {
  group('AppBreakpoints.fromWidth', () {
    test('classifies each band', () {
      expect(AppBreakpoints.fromWidth(320), Breakpoint.compact);
      expect(AppBreakpoints.fromWidth(375), Breakpoint.compact);
      expect(AppBreakpoints.fromWidth(599), Breakpoint.compact);

      expect(AppBreakpoints.fromWidth(600), Breakpoint.medium);
      expect(AppBreakpoints.fromWidth(700), Breakpoint.medium);
      expect(AppBreakpoints.fromWidth(834), Breakpoint.medium); // iPad portrait
      expect(AppBreakpoints.fromWidth(899), Breakpoint.medium);

      expect(AppBreakpoints.fromWidth(900), Breakpoint.expanded);
      expect(AppBreakpoints.fromWidth(1100), Breakpoint.expanded);
      expect(AppBreakpoints.fromWidth(1299), Breakpoint.expanded);

      expect(AppBreakpoints.fromWidth(1300), Breakpoint.large);
      expect(AppBreakpoints.fromWidth(1600), Breakpoint.large);
      expect(AppBreakpoints.fromWidth(2560), Breakpoint.large);
    });

    test('degrades to compact rather than throwing on a degenerate width', () {
      // A LayoutBuilder can report these mid-layout. Crashing there would be
      // far worse than being briefly wrong.
      expect(AppBreakpoints.fromWidth(0), Breakpoint.compact);
      expect(AppBreakpoints.fromWidth(-100), Breakpoint.compact);
      expect(AppBreakpoints.fromWidth(double.infinity), Breakpoint.compact);
      expect(AppBreakpoints.fromWidth(double.nan), Breakpoint.compact);
    });
  });

  group('the thresholds themselves', () {
    // The two upper thresholds are 900 and 1300 because the app shipped a
    // three-tier system with those boundaries first, and reusing them is what
    // let four tiers land without moving any existing layout: `expanded` plus
    // `large` cover exactly the old tablet-or-desktop band, so `medium` was the
    // only place behaviour changed.
    //
    // The old `AppDimensions.breakpointMobile` / `breakpointDesktop` constants
    // that used to be asserted against here were deleted in RESP_10 along with
    // the deprecated getters that read them. The thresholds are still
    // load-bearing, so pin the literals: a 950dp window must keep getting the
    // rail-and-tablet treatment it has always had.

    test('600 / 900 / 1300 are the boundaries', () {
      expect(AppBreakpoints.compactMax, 600);
      expect(AppBreakpoints.mediumMax, 900);
      expect(AppBreakpoints.expandedMax, 1300);
    });

    test('everything below 900 is compact or medium', () {
      for (final width in [320.0, 375.0, 599.0, 600.0, 834.0, 899.0]) {
        expect(
          AppBreakpoints.fromWidth(width).below(Breakpoint.expanded),
          isTrue,
          reason: '$width must be compact or medium',
        );
      }
    });

    test('900-1299 is exactly expanded', () {
      for (final width in [900.0, 1100.0, 1299.0]) {
        expect(AppBreakpoints.fromWidth(width), Breakpoint.expanded);
      }
    });

    test('1300 and up is exactly large', () {
      for (final width in [1300.0, 1600.0, 2560.0]) {
        expect(AppBreakpoints.fromWidth(width), Breakpoint.large);
      }
    });
  });

  group('ordering', () {
    test('atLeast and below agree with declaration order', () {
      expect(Breakpoint.large.atLeast(Breakpoint.compact), isTrue);
      expect(Breakpoint.large.atLeast(Breakpoint.large), isTrue);
      expect(Breakpoint.compact.atLeast(Breakpoint.medium), isFalse);

      expect(Breakpoint.compact.below(Breakpoint.expanded), isTrue);
      expect(Breakpoint.large.below(Breakpoint.large), isFalse);
    });

    test('values are declared narrowest first', () {
      // atLeast/below compare by index, so this ordering is load-bearing.
      expect(Breakpoint.values, [
        Breakpoint.compact,
        Breakpoint.medium,
        Breakpoint.expanded,
        Breakpoint.large,
      ]);
    });
  });
}
