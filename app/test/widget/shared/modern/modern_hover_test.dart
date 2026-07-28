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
