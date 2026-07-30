import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/test_helpers.dart';

/// A `Container` clips its child to the *outer* rounded rect and paints its
/// decoration underneath it. So an outlined card whose child bleeds to the edge
/// - a product photo in the grid, which is exactly what those cards hold -
/// painted straight over the 1px border. Along the straight edges that costs a
/// pixel nobody notices; at the corners the child's antialiased curve and the
/// border's antialiased curve land on the same pixels, and the border comes out
/// ragged or gone. It was reported as the grid's top-left and top-right corners
/// looking unbordered once hover or selection coloured that border.
///
/// The fix is to paint the border as a foreground decoration, over the child.
/// These tests assert the paint order rather than the pixels: order is what is
/// structural here, and a rasterised corner check would only restate it.
void main() {
  const border = Color(0xFFFF0000);
  const fill = Color(0xFF0000FF);

  AnimatedContainer surfaceOf(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(ModernCard),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

  /// An outlined card filled edge to edge by an opaque child - the photo's
  /// stand-in.
  Widget cardWithFullBleedChild() => const Center(
        child: ModernCard.outlined(
          onTap: _noop,
          padding: EdgeInsets.zero,
          borderColor: border,
          child: SizedBox(
            width: 120,
            height: 120,
            child: ColoredBox(color: fill),
          ),
        ),
      );

  testWidgets('the border is a foreground decoration, not a background one',
      (tester) async {
    await tester
        .pumpWidget(createTestableWidget(child: cardWithFullBleedChild()));

    final surface = surfaceOf(tester);

    expect(
      (surface.decoration! as BoxDecoration).border,
      isNull,
      reason: 'a border in the background decoration is painted under the '
          'child, and the clip eats it at the corners',
    );
    expect((surface.foregroundDecoration! as BoxDecoration).border, isNotNull);
  });

  testWidgets('the border paints after an opaque, full-bleed child',
      (tester) async {
    await tester
        .pumpWidget(createTestableWidget(child: cardWithFullBleedChild()));

    expect(
      tester.renderObject(find.byType(ModernCard)),
      paints
        // The child, filling the card to its edges...
        ..rect(color: fill)
        // ...and the border's ring drawn over it, so every corner closes.
        ..drrect(color: border),
    );
  });

  testWidgets('an unbordered variant has no foreground decoration at all',
      (tester) async {
    await tester.pumpWidget(createTestableWidget(
      child: const Center(
        child: ModernCard.elevated(
          onTap: _noop,
          child: SizedBox(width: 120, height: 120),
        ),
      ),
    ));

    expect(surfaceOf(tester).foregroundDecoration, isNull);
  });
}

void _noop() {}
