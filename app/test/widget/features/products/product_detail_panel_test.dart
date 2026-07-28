import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/products/presentation/providers/products_provider.dart';
import 'package:kasbon_pos/features/products/presentation/widgets/product_detail_panel.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_profitability.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/profit_report_provider.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

/// The panel is what the split view docks beside the list, in place of the
/// full [ProductDetailScreen]. What it must not carry is screen chrome - a
/// second app bar inside the window's content area - and what it must keep
/// reachable is the actions, however long the product's detail runs.
void main() {
  final product = MockData.createProduct(
    id: 'p1',
    name: 'Kopi Susu',
    sku: 'SKU-00001',
    costPrice: 8000,
    sellingPrice: 12000,
    stock: 24,
  );

  Widget panel({VoidCallback? onClose}) => ProductDetailPanel(
        productId: 'p1',
        onClose: onClose ?? () {},
      );

  final overrides = [
    productProvider.overrideWith((ref, id) async => product),
    productProfitabilityProvider.overrideWith(
      (ref, id) async => ProductProfitability.empty(id, 'Kopi Susu'),
    ),
  ];

  testWidgets('leads with the product, not with an app bar', (tester) async {
    await pumpAtWidth(
      tester,
      ResponsiveWidths.expanded,
      panel(),
      providerOverrides: overrides,
    );

    expect(find.text('Kopi Susu'), findsWidgets);
    expect(find.text('SKU-00001'), findsWidgets);
    // The pane is inside another screen's content area; a second header bar
    // there is the giveaway that a screen was docked without being adapted.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(ModernAppBar), findsNothing);
  });

  testWidgets('keeps the actions pinned below the scrolling body',
      (tester) async {
    await pumpAtWidth(
      tester,
      ResponsiveWidths.expanded,
      panel(),
      providerOverrides: overrides,
      // Deliberately short, so the body has to scroll and a footer that
      // scrolled with it would leave the screen.
      height: 500,
    );

    final footerBefore = tester.getTopLeft(find.text('Hapus')).dy;

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(find.text('Edit'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Hapus')).dy, footerBefore);
  });

  testWidgets('closes through the callback it was given', (tester) async {
    var closed = 0;

    await pumpAtWidth(
      tester,
      ResponsiveWidths.expanded,
      panel(onClose: () => closed++),
      providerOverrides: overrides,
    );

    await tester.tap(find.byKey(ProductDetailPanel.closeButtonKey));
    await tester.pump();

    expect(closed, 1);
  });
}
