import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/theme/app_colors.dart';
import 'package:kasbon_pos/config/theme/app_gradients.dart';
import 'package:kasbon_pos/shared/brand/kasbon_mark.dart';

/// The mark is drawn twice in this project - once by `brand/geometry.py` for
/// the shipped icons, once by [KasbonMark] for the running app. These tests
/// pin the numbers that have to agree, because a drift between them is
/// invisible in code review and only shows up as a logo that does not match
/// the icon on the home screen.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  group('KasbonMark', () {
    testWidgets('claims exactly the box it inks', (tester) async {
      await pump(tester, const KasbonMark(size: 87));

      // GLYPH_BBOX in brand/geometry.py is 72.5 x 87. Sizing is by height, so
      // an 87-tall mark is 72.5 wide - not 87 square. A square box would leave
      // the mark visibly off-centre inside anything that centres it.
      final box = tester.getSize(find.byType(KasbonMark));
      expect(box.height, 87);
      expect(box.width, closeTo(72.5, 0.01));
    });

    testWidgets('scales without distorting', (tester) async {
      await pump(tester, const KasbonMark(size: 24));

      final box = tester.getSize(find.byType(KasbonMark));
      expect(box.width / box.height, closeTo(72.5 / 87.0, 0.001));
    });
  });

  group('KasbonLogoTile', () {
    testWidgets('is the shipped icon: brand gradient, proportional corner',
        (tester) async {
      await pump(tester, const KasbonLogoTile(size: 512));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(KasbonLogoTile),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;

      // Not AppGradients.primaryCard - that one runs blue to purple and would
      // not match any icon the project ships.
      expect(decoration.gradient, AppGradients.brandMark);

      // CORNER_FRAC in brand/generate.py: 112 of 512.
      final radius = (decoration.borderRadius! as BorderRadius).topLeft.x;
      expect(radius, closeTo(112, 0.01));
    });

    testWidgets('glyph takes half the tile, in the on-primary colour',
        (tester) async {
      await pump(tester, const KasbonLogoTile(size: 200));

      final mark = tester.widget<KasbonMark>(find.byType(KasbonMark));
      expect(mark.size, 100); // TILE_FRAC = 0.50
      expect(mark.color, AppColors.onPrimary);
    });

    testWidgets('glow is opt-out for dense surfaces', (tester) async {
      await pump(tester, const KasbonLogoTile(size: 80, glow: false));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(KasbonLogoTile),
          matching: find.byType(Container),
        ),
      );
      expect((container.decoration! as BoxDecoration).boxShadow, isNull);
    });
  });
}
