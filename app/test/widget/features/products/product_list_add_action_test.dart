import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/presentation/providers/products_provider.dart';
import 'package:kasbon_pos/features/products/presentation/screens/product_list_screen.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

/// Where "Tambah Produk" lives depends on what is holding the device.
///
/// A FAB is a phone affordance: reachable by a thumb, and forgivable when it
/// covers the last row of a scrolling list. Given a pointer and a toolbar it is
/// the wrong shape - so off a phone the action moves into the filter bar, and
/// the FAB goes away rather than the two of them both offering it.
void main() {
  final products = [
    MockData.createProduct(id: 'p1', name: 'Kopi Susu', sku: 'SKU-00001'),
    MockData.createProduct(id: 'p2', name: 'Teh Manis', sku: 'SKU-00002'),
  ];

  List<Override> overrides(List<Product> items) => [
        categoriesProvider.overrideWith((ref) async => <Category>[]),
        paginatedProductsProvider.overrideWith(
          (ref) async => PaginatedResult<Product>(
            items: items,
            totalCount: items.length,
            currentPage: 1,
            pageSize: 20,
          ),
        ),
      ];

  Future<void> pumpList(
    WidgetTester tester,
    double width, {
    /// Wraps the list in a pane scope of [paneWidth], as the split view does.
    double? paneWidth,
  }) async {
    Widget list = const ProductListPane();

    if (paneWidth != null) {
      list = Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: paneWidth,
          child: ModernBreakpointScope.fromLayout(isPane: true, child: list),
        ),
      );
    }

    await pumpAtWidth(
      tester,
      width,
      list,
      providerOverrides: overrides(products),
    );
  }

  testWidgets('a phone keeps the floating button', (tester) async {
    await pumpList(tester, ResponsiveWidths.compact);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Tambah Produk'), findsNothing);
  });

  testWidgets('a tablet trades it for a button in the filter bar',
      (tester) async {
    await pumpList(tester, ResponsiveWidths.medium);

    expect(find.byType(FloatingActionButton), findsNothing);
    // Short label at this tier: the row already carries a view toggle and a
    // sort dropdown.
    expect(find.text('Tambah'), findsOneWidget);
  });

  testWidgets('a desktop spells the action out', (tester) async {
    await pumpList(tester, ResponsiveWidths.large);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Tambah Produk'), findsOneWidget);
  });

  testWidgets('a narrow master pane is not a phone', (tester) async {
    // The list squeezed below 600dp by the detail panel beside it. Its filter
    // bar is the compact one, so the action is an icon - but it is still in the
    // bar, because the window around it is a desktop.
    await pumpList(tester, ResponsiveWidths.large, paneWidth: 420);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Tambah Produk'), findsOneWidget);
  });
}
