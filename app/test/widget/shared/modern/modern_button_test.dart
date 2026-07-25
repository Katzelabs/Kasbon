import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('ModernButton', () {
    group('basic rendering', () {
      testWidgets('displays child text', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Test Button'),
            onPressed: () {},
          ),
        ));

        expect(find.text('Test Button'), findsOneWidget);
      });

      testWidgets('displays using label factory', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.label(
            label: 'Label Button',
            onPressed: () {},
          ),
        ));

        expect(find.text('Label Button'), findsOneWidget);
      });
    });

    group('button variants', () {
      testWidgets('renders primary button', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Primary'),
            onPressed: () {},
          ),
        ));

        expect(find.text('Primary'), findsOneWidget);
      });

      testWidgets('renders secondary button', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.secondary(
            child: const Text('Secondary'),
            onPressed: () {},
          ),
        ));

        expect(find.text('Secondary'), findsOneWidget);
      });

      testWidgets('renders outline button', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.outline(
            child: const Text('Outline'),
            onPressed: () {},
          ),
        ));

        expect(find.text('Outline'), findsOneWidget);
      });

      testWidgets('renders text button', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.text(
            child: const Text('Text'),
            onPressed: () {},
          ),
        ));

        expect(find.text('Text'), findsOneWidget);
      });

      testWidgets('renders destructive button', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.destructive(
            child: const Text('Delete'),
            onPressed: () {},
          ),
        ));

        expect(find.text('Delete'), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;

        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Tap Me'),
            onPressed: () => pressed = true,
          ),
        ));

        await tester.tap(find.text('Tap Me'));
        await tester.pump();

        expect(pressed, true);
      });

      testWidgets('does not call onPressed when disabled', (tester) async {
        var pressed = false;

        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Disabled'),
            onPressed: null,
          ),
        ));

        await tester.tap(find.text('Disabled'));
        await tester.pump();

        expect(pressed, false);
      });
    });

    group('loading state', () {
      testWidgets('shows loading indicator when isLoading is true',
          (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Loading'),
            onPressed: () {},
            isLoading: true,
          ),
        ));

        expect(find.byType(ModernLoading), findsOneWidget);
      });

      testWidgets('does not call onPressed when loading', (tester) async {
        var pressed = false;

        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Loading'),
            onPressed: () => pressed = true,
            isLoading: true,
          ),
        ));

        await tester.tap(find.text('Loading'));
        await tester.pump();

        expect(pressed, false);
      });
    });

    group('icons', () {
      testWidgets('displays leading icon', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('With Icon'),
            onPressed: () {},
            leadingIcon: Icons.add,
          ),
        ));

        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('displays trailing icon', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('With Icon'),
            onPressed: () {},
            trailingIcon: Icons.arrow_forward,
          ),
        ));

        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      });

      testWidgets('hides leading icon when loading', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Loading'),
            onPressed: () {},
            leadingIcon: Icons.add,
            isLoading: true,
          ),
        ));

        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byType(ModernLoading), findsOneWidget);
      });
    });

    group('fullWidth', () {
      testWidgets('takes full width when fullWidth is true', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernButton.primary(
            child: const Text('Full Width'),
            onPressed: () {},
            fullWidth: true,
          ),
        ));

        // Find the SizedBox with infinity width
        final sizedBox = tester.widget<SizedBox>(find.ancestor(
          of: find.text('Full Width'),
          matching: find.byType(SizedBox),
        ).first);

        expect(sizedBox.width, double.infinity);
      });
    });
  });
}
