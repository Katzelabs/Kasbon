import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/pos_pagination_provider.dart';
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

void main() {
  setUp(() {
    final catalogue = List.generate(
      60,
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

  /// How many tiles share the topmost row - i.e. the grid's column count.
  int columnsInFirstRow(WidgetTester tester) {
    final tiles = find.byType(ProductGridItem);
    final top = tester.getTopLeft(tiles.first).dy;

    var count = 0;
    for (var i = 0; i < tester.widgetList(tiles).length; i++) {
      if (tester.getTopLeft(tiles.at(i)).dy == top) count++;
    }
    return count;
  }

  group('layout by tier', () {
    testWidgets('compact keeps the cart in a sheet behind the summary bar',
        (tester) async {
      await pumpPos(tester, ResponsiveWidths.compact);

      expect(find.byType(CartPanel), findsNothing);
      expect(find.byType(CartSummaryBar), findsOneWidget);
    });

    testWidgets('medium keeps the overlay too - a docked cart would not fit',
        (tester) async {
      // 700dp minus a 320dp cart is under 300dp of grid: one column. This is
      // the tier the epic exists for, so it is worth pinning that widening the
      // window into it does *not* dock the cart.
      await pumpPos(tester, ResponsiveWidths.medium);

      expect(find.byType(CartPanel), findsNothing);
      expect(find.byType(CartSummaryBar), findsOneWidget);
    });

    testWidgets('expanded docks the cart beside the grid', (tester) async {
      await pumpPos(tester, ResponsiveWidths.expanded);

      expect(find.byType(CartPanel), findsOneWidget);
      expect(find.byType(CartSummaryBar), findsNothing);
    });

    testWidgets('large docks the cart and gives it more room than expanded',
        (tester) async {
      await pumpPos(tester, ResponsiveWidths.large);
      final atLarge = tester.getSize(find.byType(CartPanel)).width;

      expect(atLarge, closeTo(448, 1));
    });
  });

  group('grid columns derive from the measured pane', () {
    testWidgets('a phone gets two columns', (tester) async {
      await pumpPos(tester, ResponsiveWidths.compact);

      expect(columnsInFirstRow(tester), 2);
    });

    testWidgets('a wider window gets more, without a column ladder to say so',
        (tester) async {
      await pumpPos(tester, ResponsiveWidths.compact);
      final atCompact = columnsInFirstRow(tester);

      await pumpPos(tester, ResponsiveWidths.large);
      final atLarge = columnsInFirstRow(tester);

      expect(atLarge, greaterThan(atCompact));
    });

    testWidgets('collapsing the cart widens the grid, and the grid notices',
        (tester) async {
      // The old code computed this from the cart's and the rail's *state*.
      // Now the cart's width is simply gone from the pane the grid measures,
      // and the max-extent delegate does the rest.
      await pumpPos(tester, ResponsiveWidths.large);
      final withCart = columnsInFirstRow(tester);

      await tester.tap(find.byKey(CartPanel.closeButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(CartPanel), findsNothing);
      expect(columnsInFirstRow(tester), greaterThan(withCart));
    });
  });

  group('cart expansion survives a resize', () {
    testWidgets('1600 -> 700 -> 1600 keeps the cart collapsed', (tester) async {
      // The acceptance case for moving `_isCartExpanded` out of `setState`.
      // A tier change is a parent rebuild, so the old local flag was discarded
      // on the way down to 700 and the cart reappeared expanded on the way
      // back - undoing a choice the cashier had made deliberately.
      await pumpPos(tester, ResponsiveWidths.large);

      await tester.tap(find.byKey(CartPanel.closeButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(CartPanel), findsNothing);

      setViewWidth(tester, ResponsiveWidths.medium);
      await tester.pumpAndSettle();
      expect(find.byType(CartSummaryBar), findsOneWidget);

      setViewWidth(tester, ResponsiveWidths.large);
      await tester.pumpAndSettle();

      expect(
        find.byType(CartPanel),
        findsNothing,
        reason: 'the cart re-expanded across the resize',
      );
    });

    testWidgets('an expanded cart is still expanded after the round trip',
        (tester) async {
      await pumpPos(tester, ResponsiveWidths.large);
      expect(find.byType(CartPanel), findsOneWidget);

      setViewWidth(tester, ResponsiveWidths.medium);
      await tester.pumpAndSettle();

      setViewWidth(tester, ResponsiveWidths.large);
      await tester.pumpAndSettle();

      expect(find.byType(CartPanel), findsOneWidget);
    });
  });

  testWidgets('one page fills more than the load-more threshold',
      (tester) async {
    // The refetch storm: at page size 10 and six columns a page was 1.6 rows,
    // so the 200dp trigger was already satisfied the moment the page landed.
    // Asserting on the loaded page rather than the rendered tiles, since a
    // `GridView.builder` only builds what is on screen.
    await pumpPos(tester, ResponsiveWidths.large);

    final columns = columnsInFirstRow(tester);
    final rowsPerPage = kPosProductsPageSize / columns;
    expect(
      rowsPerPage,
      greaterThanOrEqualTo(3),
      reason: '$kPosProductsPageSize products across $columns columns is only '
          '${rowsPerPage.toStringAsFixed(1)} rows',
    );
  });
}
