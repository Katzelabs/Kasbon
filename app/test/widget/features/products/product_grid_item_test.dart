import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/presentation/widgets/product_grid_item.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

/// The card sizes itself now: [ProductGridItem.extentFor] states the height a
/// card of a given width needs, and the grid grants exactly that. The contract
/// only holds if the card actually fits inside it - at a phone's two-up width,
/// at a desktop's, and with the text scaled up by the platform.
void main() {
  Product product({int stock = 24, int minStock = 5}) => MockData.createProduct(
        id: 'p1',
        name: 'Kopi Susu Gula Aren Spesial Ukuran Besar',
        sku: 'SKU-00001',
        sellingPrice: 125000,
        stock: stock,
        minStock: minStock,
      );

  /// Pumps one card in a box exactly the size the grid would give it.
  Future<void> pumpCard(
    WidgetTester tester,
    Product item, {
    required double tileWidth,
    double textScale = 1,
  }) async {
    await pumpAtWidth(
      tester,
      ResponsiveWidths.large,
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Builder(
          builder: (context) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: tileWidth,
              height: ProductGridItem.extentFor(context, tileWidth),
              child: ProductGridItem(product: item, onTap: () {}),
            ),
          ),
        ),
      ),
    );
  }

  group('fits the height it asks for', () {
    // A phone's two-up tile, a desktop's, and the boundary between the two
    // type scales - the last being where an off-by-a-line error would land.
    for (final tileWidth in <double>[140, ProductGridItem.roomyWidth, 240]) {
      for (final textScale in <double>[1.0, 1.3]) {
        testWidgets('at ${tileWidth}dp, text x$textScale', (tester) async {
          await pumpCard(
            tester,
            product(),
            tileWidth: tileWidth,
            textScale: textScale,
          );

          // A RenderFlex overflow is reported as an exception, so this is the
          // whole assertion: the card fit in the extent it asked for.
          expect(tester.takeException(), isNull);
          expect(find.text('SKU-00001'), findsOneWidget);
        });
      }
    }
  });

  testWidgets('a taller text scale asks the grid for a taller card',
      (tester) async {
    late double plain;
    late double scaled;

    await pumpAtWidth(
      tester,
      ResponsiveWidths.large,
      Builder(
        builder: (context) {
          plain = ProductGridItem.extentFor(context, 200);
          return MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Builder(
              builder: (context) {
                scaled = ProductGridItem.extentFor(context, 200);
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );

    expect(scaled, greaterThan(plain));
    // The photo is square whatever the type does, so only the text block grew.
    expect(scaled - plain, lessThan(60));
  });

  group('stock status on the photo', () {
    testWidgets('flags an empty shelf', (tester) async {
      await pumpCard(tester, product(stock: 0), tileWidth: 200);

      expect(find.text('Habis'), findsOneWidget);
    });

    testWidgets('flags one about to empty', (tester) async {
      await pumpCard(tester, product(stock: 3), tileWidth: 200);

      expect(find.text('Menipis'), findsOneWidget);
    });

    testWidgets('says nothing when the stock is healthy', (tester) async {
      await pumpCard(tester, product(stock: 40), tileWidth: 200);

      expect(find.text('Habis'), findsNothing);
      expect(find.text('Menipis'), findsNothing);
    });
  });
}
