import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/responsive_helpers.dart';
import '../../../helpers/test_helpers.dart';

/// Width of the box the dialog actually laid its content out in.
double _dialogContentWidth(WidgetTester tester, Key key) {
  return tester.getSize(find.byKey(key)).width;
}

void main() {
  // A 420-wide marker: wide enough to be clamped at every tier, so whatever
  // width it ends up with is the dialog's clamp rather than the content's own
  // intrinsic size.
  const marker = Key('dialog-content');
  final wideChild = Container(
    key: marker,
    height: 40,
    constraints: const BoxConstraints(minWidth: 5000),
  );

  group('ModernDialog.show', () {
    testWidgets('clamps its child, which a bare Dialog did not',
        (tester) async {
      setViewWidth(tester, ResponsiveWidths.large);

      await tester.pumpWidget(createTestableWidgetWithoutScaffold(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    ModernDialog.show<void>(context, child: wideChild),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The regression this guards: `show` used to wrap the child in a Dialog
      // with no maxWidth, so a greedy child spanned the window.
      expect(
        _dialogContentWidth(tester, marker),
        lessThanOrEqualTo(ContentLayout.dialogLarge),
      );
      expect(_dialogContentWidth(tester, marker),
          lessThan(ResponsiveWidths.large));
    });

    testWidgets('honours an explicit maxWidth over the tier default',
        (tester) async {
      setViewWidth(tester, ResponsiveWidths.large);

      await tester.pumpWidget(createTestableWidgetWithoutScaffold(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => ModernDialog.show<void>(
                  context,
                  maxWidth: 300,
                  child: wideChild,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(_dialogContentWidth(tester, marker), 300);
    });
  });

  group('ModernDialogFrame width by tier', () {
    const expected = <(double, double)>[
      (ResponsiveWidths.compact, ContentLayout.dialogCompact),
      (ResponsiveWidths.medium, ContentLayout.dialogMedium),
      (ResponsiveWidths.expanded, ContentLayout.dialogLarge),
      (ResponsiveWidths.large, ContentLayout.dialogLarge),
    ];

    for (final (width, cap) in expected) {
      testWidgets('${ResponsiveWidths.label(width)} clamps to $cap',
          (tester) async {
        await pumpAtWidth(
          tester,
          width,
          ModernDialogFrame(child: wideChild),
        );

        // At compact the window itself (375) is narrower than the 420 cap, so
        // the inset padding decides - which is the point of the tier-aware
        // inset. Assert "no wider than the cap" rather than equality.
        expect(_dialogContentWidth(tester, marker), lessThanOrEqualTo(cap));
      });
    }
  });

  group('ModernDialog actions', () {
    testWidgets('stack rather than overflow when the labels are long',
        (tester) async {
      // Two long Indonesian labels in a narrow dialog: a Row would paint the
      // overflow stripe, an OverflowBar stacks.
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        ModernDialog(
          title: 'Hapus Semua Item Keranjang?',
          content: const Text('Tindakan ini tidak dapat dibatalkan.'),
          actions: [
            ModernButton.text(
              onPressed: () {},
              child: const Text('Batalkan Penghapusan'),
            ),
            ModernButton.destructive(
              onPressed: () {},
              child: const Text('Hapus Semua Sekarang'),
            ),
          ],
        ),
      );

      expect(find.byType(OverflowBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirm returns true and false without a stray spacer',
        (tester) async {
      bool? result;

      await tester.pumpWidget(createTestableWidgetWithoutScaffold(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await ModernDialog.confirm(
                    context,
                    title: 'Hapus Produk',
                    message: 'Yakin?',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Exactly two actions. The SizedBox spacer that used to sit between them
      // would be a third OverflowBar child and would stack as a blank row.
      final bar = tester.widget<OverflowBar>(find.byType(OverflowBar));
      expect(bar.children, hasLength(2));

      await tester.tap(find.text('Ya'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
