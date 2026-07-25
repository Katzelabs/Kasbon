import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('ModernTextField', () {
    group('basic rendering', () {
      testWidgets('displays label', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            label: 'Test Label',
          ),
        ));

        expect(find.text('Test Label'), findsOneWidget);
      });

      testWidgets('displays hint text', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            hint: 'Enter text here',
          ),
        ));

        expect(find.text('Enter text here'), findsOneWidget);
      });

      testWidgets('displays helper text', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            helperText: 'Helper message',
          ),
        ));

        expect(find.text('Helper message'), findsOneWidget);
      });

      testWidgets('displays error text', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            errorText: 'Error message',
          ),
        ));

        expect(find.text('Error message'), findsOneWidget);
      });
    });

    group('text input', () {
      testWidgets('accepts text input', (tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(createTestableWidget(
          child: ModernTextField(
            controller: controller,
          ),
        ));

        await tester.enterText(find.byType(TextFormField), 'Test input');
        expect(controller.text, 'Test input');
      });

      testWidgets('calls onChanged when text changes', (tester) async {
        String? changedValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernTextField(
            onChanged: (value) => changedValue = value,
          ),
        ));

        await tester.enterText(find.byType(TextFormField), 'New value');
        expect(changedValue, 'New value');
      });

      testWidgets('calls onSubmitted when submitted', (tester) async {
        String? submittedValue;

        await tester.pumpWidget(createTestableWidget(
          child: ModernTextField(
            onSubmitted: (value) => submittedValue = value,
          ),
        ));

        await tester.enterText(find.byType(TextFormField), 'Submitted value');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(submittedValue, 'Submitted value');
      });
    });

    group('disabled state', () {
      testWidgets('is disabled when enabled is false', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            enabled: false,
          ),
        ));

        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.enabled, false);
      });

      testWidgets('is read-only when readOnly is true', (tester) async {
        final controller = TextEditingController(text: 'Initial');

        await tester.pumpWidget(createTestableWidget(
          child: ModernTextField(
            controller: controller,
            readOnly: true,
          ),
        ));

        await tester.enterText(find.byType(TextFormField), 'New text');
        // In read-only mode, text should not change
        expect(controller.text, 'Initial');
      });
    });

    group('validation', () {
      testWidgets('calls validator function', (tester) async {
        String? validatorCalled;

        await tester.pumpWidget(createTestableWidget(
          child: Form(
            autovalidateMode: AutovalidateMode.always,
            child: ModernTextField(
              validator: (value) {
                validatorCalled = value;
                return value?.isEmpty == true ? 'Required' : null;
              },
            ),
          ),
        ));

        await tester.pump();
        expect(validatorCalled, '');
      });
    });

    group('prefixes and suffixes', () {
      testWidgets('displays leading widget', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            leading: Icon(Icons.email),
          ),
        ));

        expect(find.byIcon(Icons.email), findsOneWidget);
      });

      testWidgets('displays trailing widget', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            trailing: Icon(Icons.visibility),
          ),
        ));

        expect(find.byIcon(Icons.visibility), findsOneWidget);
      });

      testWidgets('trailing tap callback works', (tester) async {
        var tapped = false;

        await tester.pumpWidget(createTestableWidget(
          child: ModernTextField(
            trailing: const Icon(Icons.clear),
            onTrailingTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        expect(tapped, true);
      });
    });

    group('multiline', () {
      testWidgets('renders multiline text field', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: ModernTextField.multiline(
            maxLines: 4,
          ),
        ));

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byType(ModernTextField), findsOneWidget);
      });
    });

    group('initial value', () {
      testWidgets('displays initial value', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            initialValue: 'Initial text',
          ),
        ));

        expect(find.text('Initial text'), findsOneWidget);
      });
    });

    group('keyboard type', () {
      testWidgets('renders with number keyboard type', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            keyboardType: TextInputType.number,
          ),
        ));

        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('max length', () {
      testWidgets('renders with max length constraint', (tester) async {
        await tester.pumpWidget(createTestableWidget(
          child: const ModernTextField(
            maxLength: 10,
          ),
        ));

        expect(find.byType(TextFormField), findsOneWidget);
        // Max length shows a counter when set
        expect(find.textContaining('0/10'), findsOneWidget);
      });
    });
  });

  group('ModernPasswordField', () {
    testWidgets('hides text by default', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        child: const ModernPasswordField(
          label: 'Password',
        ),
      ));

      // Find the underlying TextField and check obscureText
      final textField = tester.widget<ModernTextField>(find.byType(ModernTextField));
      expect(textField.obscureText, true);
    });

    testWidgets('toggles visibility on icon tap', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        child: const ModernPasswordField(
          label: 'Password',
        ),
      ));

      // Initially hidden (visibility icon shown)
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap the visibility icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Now showing (visibility_off icon shown)
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
