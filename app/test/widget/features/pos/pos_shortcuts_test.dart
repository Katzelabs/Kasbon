import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/pos_shortcuts.dart';

import '../../../helpers/test_helpers.dart';

/// What each callback recorded, so a test can assert one fired and the others
/// did not - which is most of what these bindings have to get right.
class _Fired {
  int search = 0;
  int checkout = 0;
  int clear = 0;
  int dismiss = 0;

  @override
  String toString() =>
      'search:$search checkout:$checkout clear:$clear dismiss:$dismiss';
}

void main() {
  late _Fired fired;
  late FocusNode fieldFocus;

  setUp(() {
    fired = _Fired();
    fieldFocus = FocusNode();
  });

  tearDown(() => fieldFocus.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: PosShortcuts(
        onFocusSearch: () => fired.search++,
        onCheckout: () => fired.checkout++,
        onClearCart: () => fired.clear++,
        onDismiss: () => fired.dismiss++,
        child: Column(
          children: [
            TextField(focusNode: fieldFocus),
            const Text('grid'),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Presses [key] with control held down.
  Future<void> pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('with nothing focused for typing', () {
    testWidgets('slash focuses search', (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();

      expect(fired.search, 1);
    });

    testWidgets('F2 checks out', (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      expect(fired.checkout, 1);
    });

    testWidgets('Ctrl+Enter checks out', (tester) async {
      await pump(tester);
      await pressCtrl(tester, LogicalKeyboardKey.enter);

      expect(fired.checkout, 1);
    });

    testWidgets('Ctrl+F focuses search', (tester) async {
      await pump(tester);
      await pressCtrl(tester, LogicalKeyboardKey.keyF);

      expect(fired.search, 1);
    });

    testWidgets('Ctrl+Backspace clears the cart', (tester) async {
      await pump(tester);
      await pressCtrl(tester, LogicalKeyboardKey.backspace);

      expect(fired.clear, 1);
    });

    testWidgets('Escape dismisses', (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(fired.dismiss, 1);
    });
  });

  group('while a text field has focus', () {
    testWidgets('slash types a character rather than jumping to search',
        (tester) async {
      await pump(tester);
      fieldFocus.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();

      // The cashier is typing a product name, not asking for the search box
      // they are already in.
      expect(fired.search, 0);
    });

    testWidgets('Ctrl+Backspace deletes a word rather than emptying the cart',
        (tester) async {
      await pump(tester);
      fieldFocus.requestFocus();
      await tester.pumpAndSettle();

      await pressCtrl(tester, LogicalKeyboardKey.backspace);

      // This is the binding that would do real damage if it fired here: a
      // mistyped name corrected with Ctrl+Backspace would drop the sale.
      expect(fired.clear, 0);
    });

    testWidgets('F2 and Ctrl+Enter still work - neither produces text',
        (tester) async {
      await pump(tester);
      fieldFocus.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();
      await pressCtrl(tester, LogicalKeyboardKey.enter);

      expect(fired.checkout, 2);
    });

    testWidgets('Ctrl+F still works', (tester) async {
      await pump(tester);
      fieldFocus.requestFocus();
      await tester.pumpAndSettle();

      await pressCtrl(tester, LogicalKeyboardKey.keyF);

      expect(fired.search, 1);
    });
  });

  testWidgets('an unhandled key is passed on', (tester) async {
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();

    expect(fired.toString(), 'search:0 checkout:0 clear:0 dismiss:0');
  });
}
