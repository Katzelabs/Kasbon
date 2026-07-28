import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/test_helpers.dart';

/// Moves a synthetic mouse over [finder] and leaves it there.
///
/// Returns the gesture so the caller can move it away again.
Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  /// Runs [body] with the platform reported as desktop.
  ///
  /// Reset inside the body rather than in `tearDown`: the test binding checks
  /// that foundation debug variables are unset at the end of the *body*, before
  /// tear-downs run, and fails the test if one is still set.
  Future<void> asPointerFirst(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('on a pointer-first platform', () {
    testWidgets('reports enter and exit', (tester) async {
      await asPointerFirst(() async {
        final states = <bool>[];

        await tester.pumpWidget(createTestableWidget(
          child: Center(
            child: ModernHoverBuilder(
              builder: (context, isHovered, _) {
                states.add(isHovered);
                return const SizedBox(
                  width: 100,
                  height: 100,
                  child: Text('target'),
                );
              },
            ),
          ),
        ));

        expect(states.last, isFalse);

        final gesture = await _hover(tester, find.text('target'));
        expect(states.last, isTrue);

        await gesture.moveTo(const Offset(0, 0));
        await tester.pumpAndSettle();
        expect(states.last, isFalse);
      });
    });

    testWidgets('stays false when disabled', (tester) async {
      await asPointerFirst(() async {
        final states = <bool>[];

        await tester.pumpWidget(createTestableWidget(
          child: Center(
            child: ModernHoverBuilder(
              enabled: false,
              builder: (context, isHovered, _) {
                states.add(isHovered);
                return const SizedBox(
                  width: 100,
                  height: 100,
                  child: Text('target'),
                );
              },
            ),
          ),
        ));

        await _hover(tester, find.text('target'));
        expect(states, everyElement(isFalse));
      });
    });

    testWidgets('a tappable ModernCard lifts, an inert one does not',
        (tester) async {
      await asPointerFirst(() async {
        await tester.pumpWidget(createTestableWidget(
          child: Column(
            children: [
              ModernCard.elevated(
                onTap: () {},
                child: const SizedBox(
                  width: 200,
                  height: 80,
                  child: Text('tappable'),
                ),
              ),
              const ModernCard.elevated(
                child: SizedBox(
                  width: 200,
                  height: 80,
                  child: Text('inert'),
                ),
              ),
            ],
          ),
        ));

        // An inert card has no hover machinery at all - that is the contract, not
        // an optimisation, since a card that highlights without being clickable
        // is a false affordance.
        expect(find.byType(ModernHoverBuilder), findsOneWidget);

        await _hover(tester, find.text('tappable'));
        expect(tester.takeException(), isNull);
      });
    });
  });

  _cardHoverTests();

  group('on a touch platform', () {
    testWidgets('installs no MouseRegion of its own', (tester) async {
      // Default test platform is Android. A stale highlight is a real bug on
      // touch: a finger lifting outside the widget sends no exit event, so the
      // machinery is left out entirely rather than merely ignored.
      await tester.pumpWidget(createTestableWidget(
        child: ModernHoverBuilder(
          builder: (context, isHovered, _) => Text('$isHovered'),
        ),
      ));

      expect(find.text('false'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ModernHoverBuilder),
          matching: find.byType(MouseRegion),
        ),
        findsNothing,
      );
    });
  });
}

/// Regression tests for the case that shipped broken: a desktop user moving the
/// mouse across the product grid saw nothing at all.
///
/// Two separate causes, both in `ModernCard`:
///
/// 1. `outlined` is not an elevated variant, so the hover elevation bump was
///    discarded before it reached the shadow ramp.
/// 2. The hover border was written as `borderColor ?? hoverTint`, so any caller
///    passing an explicit `borderColor` short-circuited it - and both product
///    grid items, `order_card` and the table's narrow card all pass one
///    unconditionally, to show selection.
///
/// Between them, every card in the app that a cashier actually points at had
/// zero hover feedback.
void _cardHoverTests() {
  Future<void> asPointerFirst(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  AnimatedContainer surfaceOf(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(ModernCard),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

  group('ModernCard hover is actually visible', () {
    testWidgets('an outlined card with an explicit borderColor still responds',
        (tester) async {
      await asPointerFirst(() async {
        await tester.pumpWidget(createTestableWidget(
          child: Center(
            child: ModernCard.outlined(
              onTap: () {},
              // Exactly what both product grid items do.
              borderColor: const Color(0xFFE5E7EB),
              child: const SizedBox(
                width: 200,
                height: 120,
                child: Text('produk'),
              ),
            ),
          ),
        ));

        final resting = surfaceOf(tester).decoration! as BoxDecoration;
        await _hover(tester, find.text('produk'));
        final hovered = surfaceOf(tester).decoration! as BoxDecoration;

        expect(
          hovered,
          isNot(equals(resting)),
          reason: 'an explicit borderColor swallowed the hover state',
        );
      });
    });

    testWidgets('an outlined card lifts, though outlined has no resting shadow',
        (tester) async {
      await asPointerFirst(() async {
        await tester.pumpWidget(createTestableWidget(
          child: Center(
            child: ModernCard.outlined(
              onTap: () {},
              child: const SizedBox(
                width: 200,
                height: 120,
                child: Text('produk'),
              ),
            ),
          ),
        ));

        expect(
            (surfaceOf(tester).decoration! as BoxDecoration).boxShadow, isNull);

        await _hover(tester, find.text('produk'));

        // A lift is the affordance a card grid can actually show - a 1px
        // border tint at #E5E7EB is invisible at arm's length.
        expect(
          (surfaceOf(tester).decoration! as BoxDecoration).boxShadow,
          isNotNull,
        );
      });
    });

    testWidgets('a non-interactive card gains nothing', (tester) async {
      await asPointerFirst(() async {
        await tester.pumpWidget(createTestableWidget(
          child: const Center(
            child: ModernCard.outlined(
              child: SizedBox(width: 200, height: 120, child: Text('produk')),
            ),
          ),
        ));

        await _hover(tester, find.text('produk'));

        expect(
            (surfaceOf(tester).decoration! as BoxDecoration).boxShadow, isNull);
      });
    });
  });
}
