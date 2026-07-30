import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/theme/app_colors.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../../helpers/test_helpers.dart';

/// The hairline that closes the header off from the body.
///
/// The bar and the first card under it are both white and the `flat` variant
/// carries no shadow, so without an edge the two read as one surface - most
/// visibly on a wide window, where the header is 1300dp of white with a title in
/// one corner. The line is only wanted where that is true: a `primary` bar
/// separates by hue already, and a `transparent` one is drawn over a gradient
/// header it is meant to disappear into.
void main() {
  /// The border the bar paints on its own shape, or null when it paints none.
  BorderSide? bottomSide(WidgetTester tester) {
    final shape = tester.widget<AppBar>(find.byType(AppBar)).shape;
    if (shape == null) return null;
    return (shape as Border).bottom;
  }

  Future<void> pumpBar(WidgetTester tester, ModernAppBar bar) async {
    await tester.pumpWidget(createTestableWidgetWithoutScaffold(
      child: Scaffold(appBar: bar, body: const SizedBox.shrink()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a surface-coloured bar draws one', (tester) async {
    await pumpBar(tester, const ModernAppBar(title: 'Produk'));

    expect(bottomSide(tester)?.color, AppColors.border);
  });

  testWidgets('so does the flat variant, which has no shadow to fall back on',
      (tester) async {
    await pumpBar(
      tester,
      ModernAppBar.withActions(title: 'Daftar Produk'),
    );

    expect(bottomSide(tester)?.color, AppColors.border);
  });

  testWidgets('a coloured or transparent bar does not', (tester) async {
    await pumpBar(tester, const ModernAppBar.primary(title: 'Kasir'));
    expect(bottomSide(tester), isNull);

    await pumpBar(tester, const ModernAppBar.transparent(title: 'Beranda'));
    expect(bottomSide(tester), isNull);
  });

  testWidgets('and a screen can say otherwise either way', (tester) async {
    await pumpBar(
      tester,
      const ModernAppBar(title: 'Produk', showDivider: false),
    );
    expect(bottomSide(tester), isNull);

    await pumpBar(
      tester,
      const ModernAppBar.transparent(title: 'Beranda', showDivider: true),
    );
    expect(bottomSide(tester)?.color, AppColors.border);
  });

  testWidgets('the line costs the body no height', (tester) async {
    // Drawn on the bar's shape rather than as a widget in `bottom`, which adds
    // to `preferredSize` - a 1dp divider there would push every screen's
    // content down and make the header 65dp on some screens and 64dp on others.
    const withLine = ModernAppBar(title: 'Produk');
    const without = ModernAppBar(title: 'Produk', showDivider: false);

    expect(withLine.preferredSize, without.preferredSize);
  });
}
