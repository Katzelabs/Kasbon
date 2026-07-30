import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/screens/pos_screen.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/cart_panel.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/cart_summary_bar.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/product_grid_item.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/domain/entities/product_filter.dart';
import 'package:kasbon_pos/features/products/domain/repositories/product_repository.dart';
import 'package:kasbon_pos/features/products/domain/usecases/get_paginated_products.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

class _StubProductRepository extends Mock implements ProductRepository {
  _StubProductRepository(this.catalogue);

  final List<Product> catalogue;

  @override
  Future<Either<Failure, PaginatedResult<Product>>> getProductsPaginated(
    ProductFilter filter,
  ) async {
    final start = (filter.page - 1) * filter.pageSize;
    final end = (start + filter.pageSize).clamp(0, catalogue.length);

    return Right(PaginatedResult(
      items:
          start >= catalogue.length ? const [] : catalogue.sublist(start, end),
      totalCount: catalogue.length,
      currentPage: filter.page,
      pageSize: filter.pageSize,
    ));
  }
}

/// The cart control in the POS header.
///
/// It replaces a floating button that existed only in the split layout, and
/// whose whole job was reopening a cart the cashier had collapsed - the one
/// control that had to be findable while the cart was *not* on screen. In the
/// header it is in the same place at every width, and at `medium` it gives the
/// modal cart a way in that does not depend on the summary bar, which is hidden
/// while the cart is empty.
void main() {
  setUp(() {
    final catalogue = List.generate(
      12,
      (i) => MockData.createProduct(
        id: 'prod-$i',
        name: 'Produk $i',
        sellingPrice: 5000,
        stock: 20,
      ),
    );

    getIt.registerSingleton<GetPaginatedProducts>(
      GetPaginatedProducts(_StubProductRepository(catalogue)),
    );
  });

  tearDown(() => getIt.reset());

  Future<void> pumpPos(WidgetTester tester, double width) async {
    await pumpScreenAtWidth(
      tester,
      width,
      const PosScreen(),
      providerOverrides: [
        categoriesProvider.overrideWith((ref) async => <Category>[]),
      ],
    );
  }

  /// Puts one item in the cart, by tapping the first product tile.
  Future<void> addOneProduct(WidgetTester tester) async {
    await tester.tap(find.byType(ProductGridItem).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a phone gets no header control - the summary bar is the way in',
      (tester) async {
    await pumpPos(tester, ResponsiveWidths.compact);

    expect(find.byTooltip('Keranjang'), findsNothing);
    expect(find.byType(CartSummaryBar), findsOneWidget);
  });

  testWidgets('at medium the header opens the modal cart', (tester) async {
    await pumpPos(tester, ResponsiveWidths.medium);

    // No docked cart at this tier, so nothing to toggle - the button opens the
    // sheet, and does so even with an empty cart, which the summary bar cannot.
    expect(find.byType(CartPanel), findsNothing);

    await tester.tap(find.byTooltip('Keranjang'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPanel), findsOneWidget);
  });

  testWidgets('in the split layout it toggles the docked cart both ways',
      (tester) async {
    await pumpPos(tester, ResponsiveWidths.large);

    expect(find.byType(CartPanel), findsOneWidget);

    await tester.tap(find.byTooltip('Sembunyikan Keranjang'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPanel), findsNothing);
    // No floating button left behind to offer the same thing.
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byTooltip('Tampilkan Keranjang'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPanel), findsOneWidget);
  });

  testWidgets('it carries the item count, so a hidden cart is not a black box',
      (tester) async {
    await pumpPos(tester, ResponsiveWidths.large);

    await addOneProduct(tester);
    await tester.tap(find.byTooltip('Sembunyikan Keranjang'));
    await tester.pumpAndSettle();

    // The badge is the only thing reporting the cart's contents once the panel
    // is closed.
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );
  });
}
