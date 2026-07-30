import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasbon_pos/config/routes/app_router.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/presentation/providers/products_provider.dart';
import 'package:kasbon_pos/features/products/presentation/screens/product_list_screen.dart';
import 'package:kasbon_pos/features/products/presentation/widgets/product_add_action.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';
import '../../../helpers/test_helpers.dart';

/// Where "Tambah Produk" lives depends on what is holding the device.
///
/// A FAB is a phone affordance: reachable by a thumb, and forgivable when it
/// covers the last row of a scrolling list. Given a pointer and a toolbar it is
/// the wrong shape - so off a phone the action moves into the screen's header,
/// beside the account avatar, and the FAB goes away rather than the two of them
/// both offering it.
///
/// The header is deliberately not the filter bar, which is where this lived
/// before: a primary action inside the scrolling content scrolls away, and it
/// narrowed with the master pane instead of with the window.
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

  /// Marks the add form, so a tap on the header button can be shown to arrive.
  const addFormKey = Key('add-form-stub');

  /// The list route under a shell-level breakpoint scope, as the app mounts it.
  ///
  /// The whole screen is pumped rather than [ProductListPane] alone, because the
  /// button under test is in the app bar - which is the point of the change, and
  /// which a pane-only pump cannot see.
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.products,
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: ModernBreakpointScope.fromLayout(child: child),
          ),
          routes: [
            GoRoute(
              path: AppRoutes.products,
              builder: (context, state) => const ProductListScreen(),
              routes: [
                // Before ':id', the same order the real table uses - otherwise
                // /products/add matches as a product whose id is "add".
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const Scaffold(
                    key: addFormKey,
                    body: SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpScreen(WidgetTester tester, double width) async {
    setViewWidth(tester, width);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(products),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The add button as it appears in the header, at whichever label.
  Finder headerAction(String label) => find.descendant(
        of: find.byType(ModernAppBar),
        matching: find.text(label),
      );

  testWidgets('a phone keeps the floating button and leaves the header bare',
      (tester) async {
    await pumpScreen(tester, ResponsiveWidths.compact);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    // 375dp of header holds a title and an avatar, and nothing else.
    expect(find.byType(ProductAddAction), findsOneWidget);
    expect(headerAction('Tambah'), findsNothing);
    expect(headerAction('Tambah Produk'), findsNothing);
  });

  testWidgets('a tablet trades it for a button in the header', (tester) async {
    await pumpScreen(tester, ResponsiveWidths.medium);

    expect(find.byType(FloatingActionButton), findsNothing);
    // Short label at this tier: the header also carries a title and an avatar.
    expect(headerAction('Tambah'), findsOneWidget);
  });

  testWidgets('a desktop spells the action out', (tester) async {
    await pumpScreen(tester, ResponsiveWidths.large);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(headerAction('Tambah Produk'), findsOneWidget);
  });

  testWidgets('the header button opens the add form', (tester) async {
    await pumpScreen(tester, ResponsiveWidths.large);

    await tester.tap(headerAction('Tambah Produk'));
    await tester.pumpAndSettle();

    expect(find.byKey(addFormKey), findsOneWidget);
  });

  testWidgets('a narrow master pane is not a phone', (tester) async {
    // The list squeezed below 600dp by the detail panel beside it. No FAB: the
    // window around it is a desktop, and the header spanning that window - which
    // does not narrow with this pane - is still carrying the button.
    setViewWidth(tester, ResponsiveWidths.large);

    await tester.pumpWidget(createTestableWidget(
      providerOverrides: overrides(products),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 420,
          child: ModernBreakpointScope.fromLayout(
            isPane: true,
            child: const ProductListPane(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    // And the filter bar no longer offers the action either - it moved out.
    expect(find.byTooltip('Tambah Produk'), findsNothing);
  });
}
