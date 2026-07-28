import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/test_helpers.dart';

/// A `Material` paints its ink *beneath* its child. So an interactive widget
/// built as
///
/// ```
/// Material > InkWell > Container(opaque fill)
/// ```
///
/// draws the splash and then covers it with the fill: the tap looks like
/// nothing happened. The whole Modern library was written this way, so every
/// primary button, chip, avatar, card and paginator button in the app had an
/// invisible ripple. Only the variants with no fill - `ModernButton.text`, a
/// standard `ModernIconButton` - ever showed one, which is why it survived
/// review for so long.
///
/// The fix is to nest the ink *inside* the painted box. These tests assert the
/// nesting rather than the pixels, because paint order is exactly what is
/// structural here - and a golden would pass just as happily with the splash
/// hidden, since it is only visible mid-animation.
void main() {
  /// The decorated box a widget paints its own background with.
  Finder paintedBoxOf(Type widget) => find
      .descendant(
        of: find.byType(widget),
        matching: find.byWidgetPredicate((w) =>
            (w is Container && w.decoration != null) ||
            (w is AnimatedContainer && w.decoration != null)),
      )
      .first;

  /// Asserts the ink surface is a descendant of the painted box, not an
  /// ancestor of it.
  void expectInkAbovePaint(WidgetTester tester, Type widget) {
    final box = paintedBoxOf(widget);

    expect(
      find.descendant(of: box, matching: find.byType(InkWell)),
      findsWidgets,
      reason: '$widget draws its fill over its own ink - move the Material '
          'and InkWell inside the decorated box',
    );

    // And the inverse, so a future refactor cannot satisfy the first
    // assertion by adding a second InkWell somewhere harmless.
    expect(
      find.ancestor(of: box, matching: find.byType(InkWell)),
      findsNothing,
      reason: '$widget still wraps its painted box in an InkWell',
    );
  }

  testWidgets('ModernButton', (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: Center(
        child: ModernButton.primary(
          onPressed: () {},
          child: const Text('Bayar'),
        ),
      ),
    ));

    expectInkAbovePaint(tester, ModernButton);
  });

  testWidgets('ModernIconButton', (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: Center(
        child: ModernIconButton(
          icon: Icons.add,
          variant: ModernIconButtonVariant.filled,
          onPressed: () {},
        ),
      ),
    ));

    expectInkAbovePaint(tester, ModernIconButton);
  });

  testWidgets('ModernCard', (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: Center(
        child: ModernCard.elevated(
          onTap: () {},
          child: const SizedBox(width: 200, height: 100),
        ),
      ),
    ));

    expectInkAbovePaint(tester, ModernCard);
  });

  testWidgets('ModernGradientCard', (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: Center(
        child: ModernGradientCard.primary(
          onTap: () {},
          child: const SizedBox(width: 200, height: 100),
        ),
      ),
    ));

    expectInkAbovePaint(tester, ModernGradientCard);
  });

  testWidgets('ModernChip', (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: Center(
        child: ModernChip(
          label: 'Makanan',
          selected: true,
          onSelected: (_) {},
        ),
      ),
    ));

    expectInkAbovePaint(tester, ModernChip);
  });

  testWidgets('ModernAvatar', (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: Center(
        child: ModernAvatar.initials('ZH', onTap: () {}),
      ),
    ));

    expectInkAbovePaint(tester, ModernAvatar);
  });

  testWidgets('a non-interactive widget has no ink at all', (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: const Center(
        child: ModernCard.elevated(child: SizedBox(width: 200, height: 100)),
      ),
    ));

    expect(
      find.descendant(
        of: find.byType(ModernCard),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });
}
