import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/presentation/providers/product_selection_provider.dart';
import 'package:kasbon_pos/features/products/presentation/providers/products_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../fixtures/mock_data.dart';

/// Two pre-existing bugs in the products list's selection state.
void main() {
  // `setMockInitialValues` needs the binding; without it the store the view
  // mode hydrates from is never installed.
  TestWidgetsFlutterBinding.ensureInitialized();

  final page1 = [
    MockData.createProduct(id: 'p1', name: 'Kopi'),
    MockData.createProduct(id: 'p2', name: 'Teh'),
  ];

  // The rows that exist but are *not* on the current page. Under the old
  // wiring these were part of "all products", which is what made "select all"
  // disagree with the screen.
  final page2 = [
    MockData.createProduct(id: 'p3', name: 'Susu'),
    MockData.createProduct(id: 'p4', name: 'Roti'),
  ];

  PaginatedResult<Product> pageOf(List<Product> items, int page) =>
      PaginatedResult(
        items: items,
        totalCount: page1.length + page2.length,
        currentPage: page,
        pageSize: 2,
      );

  ProviderContainer containerShowing(List<Product> items, int page) {
    final container = ProviderContainer(
      overrides: [
        paginatedProductsProvider
            .overrideWith((ref) async => pageOf(items, page)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('"select all" tracks what is on screen', () {
    test('reports selected when every rendered row is selected', () async {
      final container = containerShowing(page1, 1);
      await container.read(paginatedProductsProvider.future);

      container.read(productSelectionProvider.notifier).selectAll(['p1', 'p2']);

      expect(container.read(allProductsSelectedProvider), isTrue);
    });

    test('ignores rows on other pages', () async {
      // This is the bug. The selection providers used to read a
      // `filteredProductsProvider` that ran over *all* products with no
      // pagination, so selecting both rows of page 2 left the header checkbox
      // unticked - it was still waiting for page 1's rows, which nobody could
      // see or click.
      final container = containerShowing(page2, 2);
      await container.read(paginatedProductsProvider.future);

      container.read(productSelectionProvider.notifier).selectAll(['p3', 'p4']);

      expect(container.read(allProductsSelectedProvider), isTrue);
    });

    test('is not satisfied by selections from a page that is not shown',
        () async {
      final container = containerShowing(page1, 1);
      await container.read(paginatedProductsProvider.future);

      // Rows from page 2, while page 1 is rendered.
      container.read(productSelectionProvider.notifier).selectAll(['p3', 'p4']);

      expect(container.read(allProductsSelectedProvider), isFalse);
    });

    test('an empty page is never "all selected"', () async {
      final container = containerShowing(const [], 1);
      await container.read(paginatedProductsProvider.future);

      expect(container.read(allProductsSelectedProvider), isFalse);
    });
  });

  group('selectedProductsProvider resolves against the rendered page', () {
    test('returns the entities for ids on this page', () async {
      final container = containerShowing(page1, 1);
      await container.read(paginatedProductsProvider.future);

      container.read(productSelectionProvider.notifier).selectAll(['p1']);

      final selected = container.read(selectedProductsProvider);
      expect(selected.map((p) => p.id), ['p1']);
    });

    test('drops ids that are not on this page', () async {
      // The bulk action bar reads this to decide what to delete. Resolving an
      // id against a result set the user is not looking at is how a bulk
      // delete reaches a row that was never ticked on screen.
      final container = containerShowing(page1, 1);
      await container.read(paginatedProductsProvider.future);

      container.read(productSelectionProvider.notifier).selectAll(['p1', 'p3']);

      final selected = container.read(selectedProductsProvider);
      expect(selected.map((p) => p.id), ['p1']);
    });
  });

  group('the selection does not outlive the screen', () {
    test('is discarded once nothing is listening', () async {
      final container = containerShowing(page1, 1);

      // A listener stands in for the list screen being on-screen.
      final subscription = container.listen(
        productSelectionProvider,
        (_, __) {},
        fireImmediately: true,
      );

      container.read(productSelectionProvider.notifier).selectAll(['p1', 'p2']);
      expect(container.read(productSelectionProvider), hasLength(2));

      // Navigating away: the last listener goes, and autoDispose collects the
      // provider. Without it a bulk selection survived the trip to another
      // screen and the action bar was still offering to delete those rows on
      // the way back.
      subscription.close();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(productSelectionProvider), isEmpty);
    });
  });

  group('the view mode is remembered', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to grid with nothing stored', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(productViewModeProvider), ProductViewMode.grid);
    });

    test('writes the choice through to shared_preferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(productViewModeProvider.notifier).setMode(
            ProductViewMode.table,
          );
      expect(container.read(productViewModeProvider), ProductViewMode.table);

      // The write is async; let it land before reading the store back.
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(productViewModePrefsKey), 'table');
    });

    test('restores the stored choice on a fresh start', () async {
      SharedPreferences.setMockInitialValues({
        productViewModePrefsKey: 'table',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Grid on the first frame, because the read is off the disk.
      expect(container.read(productViewModeProvider), ProductViewMode.grid);

      await _settle();

      expect(container.read(productViewModeProvider), ProductViewMode.table);
    });

    test('a stored value that is no longer a mode is ignored', () async {
      SharedPreferences.setMockInitialValues({
        productViewModePrefsKey: 'kanban',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await _settle();

      expect(container.read(productViewModeProvider), ProductViewMode.grid);
    });

    test('a slow read does not clobber a choice made while it was in flight',
        () async {
      SharedPreferences.setMockInitialValues({
        productViewModePrefsKey: 'grid',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Toggling before hydration resolves is a real race on a cold start: the
      // list is interactive long before the platform channel answers.
      container.read(productViewModeProvider.notifier).setMode(
            ProductViewMode.table,
          );

      await _settle();

      expect(container.read(productViewModeProvider), ProductViewMode.table);
    });
  });
}

/// Lets the asynchronous `shared_preferences` read - and the write that
/// follows a change - complete before the assertion looks at the result.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
