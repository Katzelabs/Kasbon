import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/theme/app_dimensions.dart';
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

  group('the new tiers subdivide the legacy bands', () {
    // This is the property that makes RESP_03 non-breaking: every legacy
    // getter can be expressed exactly in terms of the new tiers, so the
    // forwarders lose no information. If someone edits a threshold and breaks
    // this, the deprecate-and-forward migration silently starts changing
    // layouts - so assert it rather than trusting the comment.

    test('legacy mobile (<900) is exactly compact + medium', () {
      expect(AppBreakpoints.mediumMax, AppDimensions.breakpointMobile);

      for (final width in [320.0, 375.0, 599.0, 600.0, 834.0, 899.0]) {
        final tier = AppBreakpoints.fromWidth(width);
        expect(
          tier.below(Breakpoint.expanded),
          isTrue,
          reason: '$width is legacy-mobile so must be compact or medium',
        );
      }
    });

    test('legacy tablet (900-1300) is exactly expanded', () {
      expect(AppBreakpoints.expandedMax, AppDimensions.breakpointDesktop);

      for (final width in [900.0, 1100.0, 1299.0]) {
        expect(AppBreakpoints.fromWidth(width), Breakpoint.expanded);
      }
    });

    test('legacy desktop (>=1300) is exactly large', () {
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
