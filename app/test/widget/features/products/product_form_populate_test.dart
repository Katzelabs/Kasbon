import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/services/image_storage/image_storage_service.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/presentation/providers/products_provider.dart';
import 'package:kasbon_pos/features/products/presentation/screens/product_form_screen.dart';

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

/// The bug: the form populated itself under a `_existingProduct == null`
/// guard, which answers "have I loaded anything?" rather than "have I loaded
/// *this*?". Once the form became the detail half of a split view - where
/// picking another product in the master swaps the record underneath a mounted
/// form - that guard means the user edits and saves the wrong product.
void main() {
  final productOne = MockData.createProduct(
    id: 'p1',
    name: 'Kopi Susu',
    sku: 'SKU-00001',
    stock: 12,
  );
  final productTwo = MockData.createProduct(
    id: 'p2',
    name: 'Teh Manis',
    sku: 'SKU-00002',
    stock: 40,
  );

  setUp(() {
    if (!getIt.isRegistered<ImageStorageService>()) {
      getIt.registerSingleton<ImageStorageService>(_NoopImageStorage());
    }
  });

  tearDown(() => getIt.reset());

  List<Override> overridesFor(List<Product> products) => [
        categoriesProvider.overrideWith((ref) async => <Category>[]),
        productProvider.overrideWith(
          (ref, id) async => products.firstWhere((p) => p.id == id),
        ),
      ];

  /// The text currently in the field labelled [label].
  String fieldText(WidgetTester tester, String label) {
    final field = tester.widget<TextField>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(TextField),
      ),
    );
    return field.controller?.text ?? '';
  }

  testWidgets('populates from the product it is opened on', (tester) async {
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const ProductFormScreen(productId: 'p1'),
      providerOverrides: overridesFor([productOne, productTwo]),
    );

    expect(fieldText(tester, 'Nama Produk *'), 'Kopi Susu');
    expect(fieldText(tester, 'Stok Awal'), '12');
  });

  testWidgets('re-populates when the product it is pointed at changes',
      (tester) async {
    setViewWidth(tester, ResponsiveWidths.compact);

    // Deliberately unkeyed, so the same State survives the swap. The router
    // keys this screen by id as well, but the two guards are independent and
    // this is the one that has to hold on its own.
    Widget formFor(String id) => ProviderScope(
          overrides: overridesFor([productOne, productTwo]),
          child: MaterialApp(
            home: ProductFormScreen(productId: id),
          ),
        );

    await tester.pumpWidget(formFor('p1'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'Nama Produk *'), 'Kopi Susu');

    await tester.pumpWidget(formFor('p2'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'Nama Produk *'), 'Teh Manis');
    expect(fieldText(tester, 'Stok Awal'), '40');
  });
}
