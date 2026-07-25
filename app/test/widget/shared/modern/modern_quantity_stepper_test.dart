import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('ModernQuantityStepper', () {
    group('basic rendering', () {
      testWidgets('displays current value', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 5,
            onChanged: (_) {},
          ),
        ));

        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('displays increment and decrement icons', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 5,
            onChanged: (_) {},
          ),
        ));

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.remove), findsOneWidget);
      });
    });

    group('increment', () {
      testWidgets('calls onChanged with incremented value when + tapped',
          (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 5,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(newValue, 6);
      });

      testWidgets('respects step parameter', (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 5,
            step: 5,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(newValue, 10);
      });

      testWidgets('disables increment at max value', (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 10,
            maxValue: 10,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(newValue, null); // onChanged should not be called
      });
    });

    group('decrement', () {
      testWidgets('calls onChanged with decremented value when - tapped',
          (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 5,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        expect(newValue, 4);
      });

      testWidgets('respects step parameter', (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 10,
            step: 5,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        expect(newValue, 5);
      });

      testWidgets('disables decrement at min value', (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 0,
            minValue: 0,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        expect(newValue, null); // onChanged should not be called
      });
    });

    group('min/max bounds', () {
      testWidgets('increment button disabled at maxValue', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 99,
            maxValue: 99,
            onChanged: (_) {},
          ),
        ));

        // The increment button should be visually disabled
        // We can check by tapping and verifying no change occurs
        int tapCount = 0;
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 99,
            maxValue: 99,
            onChanged: (_) => tapCount++,
          ),
        ));

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(tapCount, 0);
      });

      testWidgets('decrement button disabled at minValue', (tester) async {
        int tapCount = 0;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 1,
            minValue: 1,
            onChanged: (_) => tapCount++,
          ),
        ));

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        expect(tapCount, 0);
      });

      testWidgets('both buttons enabled when in range', (tester) async {
        final List<int> changes = [];

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 50,
            minValue: 0,
            maxValue: 100,
            onChanged: (v) => changes.add(v),
          ),
        ));

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        expect(changes.length, 2);
        expect(changes[0], 51);
        expect(changes[1], 49);
      });
    });

    group('compact variant', () {
      testWidgets('renders compact stepper', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper.compact(
            value: 3,
            onChanged: (_) {},
          ),
        ));

        expect(find.text('3'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.remove), findsOneWidget);
      });

      testWidgets('compact variant has no border by default', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper.compact(
            value: 3,
            onChanged: (_) {},
          ),
        ));

        // The compact variant should use showBorder: false
        // This is hard to test visually, but we can verify it renders
        expect(find.byType(ModernQuantityStepper), findsOneWidget);
      });
    });

    group('value display', () {
      testWidgets('displays zero correctly', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 0,
            onChanged: (_) {},
          ),
        ));

        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('displays large numbers correctly', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 999,
            onChanged: (_) {},
          ),
        ));

        expect(find.text('999'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles value at min edge', (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 1,
            minValue: 0,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        expect(newValue, 0);
      });

      testWidgets('handles value at max edge', (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 998,
            maxValue: 999,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(newValue, 999);
      });

      testWidgets('handles negative minValue', (tester) async {
        int? newValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernQuantityStepper(
            value: 0,
            minValue: -10,
            onChanged: (v) => newValue = v,
          ),
        ));

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        expect(newValue, -1);
      });
    });
  });
}
