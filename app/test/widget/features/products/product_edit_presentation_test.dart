import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/config/routes/app_router.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/core/services/image_storage/image_storage_service.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/presentation/providers/products_provider.dart';
import 'package:kasbon_pos/features/products/presentation/screens/product_form_screen.dart';
import 'package:kasbon_pos/features/products/presentation/screens/product_list_screen.dart';
import 'package:kasbon_pos/features/products/presentation/widgets/product_detail_panel.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_profitability.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/profit_report_provider.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

class _NoopImageStorage implements ImageStorageService {
  @override
  Future<void> deleteImage(String imagePath) async {}

  @override
  Future<bool> imageExists(String imagePath) async => false;

  @override
  Future<String> saveImage(PickedImage image, String productId) async => '';
}

/// Editing a product is a screen, at every width.
///
/// It used to dock in the list's detail panel on a wide window, which put a
/// seven-card form into the narrowest column on the page while the products it
/// was not about kept the wide half. This pins the replacement: the form takes
/// the window the way `/products/add` always has, and the panel it was opened
/// from is what is still there underneath when it closes.
void main() {
  final product = MockData.createProduct(
    id: 'p1',
    name: 'Kopi Susu',
    sku: 'SKU-00001',
    stock: 12,
  );

  setUp(() {
    if (!getIt.isRegistered<ImageStorageService>()) {
      getIt.registerSingleton<ImageStorageService>(_NoopImageStorage());
    }
  });

  tearDown(() => getIt.reset());

  final overrides = [
    categoriesProvider.overrideWith((ref) async => <Category>[]),
    productProvider.overrideWith((ref, id) async => product),
    productProfitabilityProvider.overrideWith(
      (ref, id) async => ProductProfitability.empty(id, 'Kopi Susu'),
    ),
    paginatedProductsProvider.overrideWith(
      (ref) async => PaginatedResult<Product>(
        items: [product],
        totalCount: 1,
        currentPage: 1,
        pageSize: 20,
      ),
    ),
  ];

  /// The products branch of the real route table, with the same page types.
  ///
  /// [AppRouter.router] itself cannot be pumped - it is a lazily initialised
  /// static that reaches for `Supabase.instance` - so this mirrors its shape:
  /// the list under a shell-level breakpoint scope, the detail behind a
  /// [SplitDetailPage], and the form on an ordinary opaque page.
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
              pageBuilder: (context, state) =>
                  const MaterialPage(child: ProductListScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => SplitDetailPage<void>(
                    key: state.pageKey,
                    transitionDuration: Duration.zero,
                    transitionsBuilder: (_, __, ___, child) => child,
                    child: const SizedBox.shrink(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      pageBuilder: (context, state) => MaterialPage(
                        key: state.pageKey,
                        child: ProductFormScreen(
                          key: const ValueKey('form-p1'),
                          productId: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<GoRouter> pumpAt(WidgetTester tester, double width) async {
    setViewWidth(tester, width);
    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the form takes the window, not the panel', (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.large);

    router.go(AppRoutes.productEditPath('p1'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductFormScreen), findsOneWidget);
    // Not docked: a form inside the pane is the arrangement this replaced.
    expect(
      find.descendant(
        of: find.byType(DetailPaneScope),
        matching: find.byType(ProductFormScreen),
      ),
      findsNothing,
    );
    // And it wears screen chrome of its own, the way /products/add does.
    expect(
      find.descendant(
        of: find.byType(ProductFormScreen),
        matching: find.byType(ModernAppBar),
      ),
      findsOneWidget,
    );
    expect(find.text('Edit Produk'), findsOneWidget);
  });

  testWidgets('closing it lands back on the product it was opened from',
      (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.large);

    router.go(AppRoutes.productEditPath('p1'));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(ProductFormScreen), findsNothing);
    // The panel, not the bare list: `go` synthesised /products -> /products/p1,
    // so one pop lands on the selection rather than dropping it.
    expect(find.byType(ProductDetailPanel), findsOneWidget);
  });

  testWidgets('a phone gets the same screen', (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.compact);

    router.go(AppRoutes.productEditPath('p1'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductFormScreen), findsOneWidget);
    expect(find.text('Edit Produk'), findsOneWidget);
  });
}
