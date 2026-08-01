import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/core/services/image_storage/image_storage_service.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/domain/repositories/product_repository.dart';
import 'package:kasbon_pos/features/products/domain/usecases/update_product.dart';
import 'package:kasbon_pos/features/products/presentation/providers/products_provider.dart';
import 'package:kasbon_pos/features/products/presentation/screens/product_form_screen.dart';
import 'package:kasbon_pos/features/products/presentation/widgets/product_image_picker.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';
import '../../../helpers/test_helpers.dart';

/// Records what reached storage, and when.
class _RecordingImageStorage implements ImageStorageService {
  final List<String> deleted = [];

  @override
  String publicUrlFor(String reference) => reference;

  @override
  Future<void> deleteImage(String imagePath) async => deleted.add(imagePath);

  @override
  Future<bool> imageExists(String imagePath) async => true;

  @override
  Future<String> saveImage(PickedImage image, String productId) async =>
      throw UnimplementedError('the picker is driven through onImageChanged');
}

/// Records what reached the row.
class _RecordingProductRepository implements ProductRepository {
  Product? updated;

  @override
  Future<Either<Failure, Product>> updateProduct(Product product) async {
    updated = product;
    return Right(product);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Storage and the row are written at different moments, and a product photo
/// is the only thing in this app that lives in both. Every case below is a way
/// they used to come apart - always in the same direction, with `image_url`
/// naming an object that had already been deleted, which renders as the
/// placeholder with no error anywhere to say why.
void main() {
  const oldImage = 'https://example.test/storage/v1/object/public/'
      'product-images/u1/p1/1000.jpg';
  const newImage = 'https://example.test/storage/v1/object/public/'
      'product-images/u1/p1/2000.jpg';

  late _RecordingImageStorage storage;
  late _RecordingProductRepository repository;

  final product = MockData.createProduct(
    id: 'p1',
    name: 'Kopi Susu',
    sku: 'SKU-00001',
    stock: 12,
    imageUrl: oldImage,
  );

  setUp(() {
    storage = _RecordingImageStorage();
    repository = _RecordingProductRepository();
    getIt.registerSingleton<ImageStorageService>(storage);
    getIt.registerSingleton<UpdateProduct>(UpdateProduct(repository));
    installInertImageCache();
  });

  tearDown(() => getIt.reset());

  final overrides = [
    categoriesProvider.overrideWith((ref) async => <Category>[]),
    productProvider.overrideWith((ref, id) async => product),
    paginatedProductsProvider.overrideWith(
      (ref) async => PaginatedResult<Product>(
        items: [product],
        totalCount: 1,
        currentPage: 1,
        pageSize: 20,
      ),
    ),
  ];

  /// The form on a page that can be popped, so leaving it disposes the State -
  /// which is where the form decides what storage may lose.
  Future<GoRouter> pumpForm(WidgetTester tester) async {
    setViewWidth(tester, ResponsiveWidths.compact);
    final router = GoRouter(
      initialLocation: '/products/p1/edit',
      routes: [
        GoRoute(
          path: '/products',
          builder: (context, state) => const Scaffold(body: Text('Daftar')),
          routes: [
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => ProductFormScreen(
                productId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    );

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

  /// Stands in for a successful pick: the picker reports a path only once the
  /// upload behind it has landed.
  void reportPickedImage(WidgetTester tester, String path) {
    tester.widget<ProductImagePicker>(find.byType(ProductImagePicker))
        .onImageChanged(path);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Perbarui'));
    await tester.pumpAndSettle();
  }

  testWidgets('a replaced photo is deleted only once the row names its '
      'replacement', (tester) async {
    await pumpForm(tester);

    reportPickedImage(tester, newImage);
    await tester.pumpAndSettle();

    // The row still points at the old object, so it is still the live photo.
    expect(storage.deleted, isEmpty);

    await save(tester);

    expect(repository.updated?.imageUrl, newImage);
    expect(storage.deleted, [oldImage]);
  });

  testWidgets('an abandoned pick leaves the row\'s photo alone', (tester) async {
    final router = await pumpForm(tester);

    reportPickedImage(tester, newImage);
    await tester.pumpAndSettle();

    router.pop();
    await tester.pumpAndSettle();

    // This is the case that produced the bug: the pick was uploaded, the save
    // never happened, and deleting the old object here left the row pointing
    // at nothing. Only the upload nobody references may go.
    expect(repository.updated, isNull);
    expect(storage.deleted, [newImage]);
  });

  testWidgets('removing a photo persists the removal and then deletes it',
      (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byType(ProductImagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Foto'));
    await tester.pumpAndSettle();

    expect(storage.deleted, isEmpty);

    await save(tester);

    // `copyWith` used to drop this null on the floor - `imageUrl ?? this
    // .imageUrl` - so the URL survived a removal that had already deleted the
    // file it named.
    expect(repository.updated, isNotNull);
    expect(repository.updated?.imageUrl, isNull);
    expect(storage.deleted, [oldImage]);
  });

  testWidgets('a removal that is not saved keeps the photo', (tester) async {
    final router = await pumpForm(tester);

    await tester.tap(find.byType(ProductImagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Foto'));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pumpAndSettle();

    expect(repository.updated, isNull);
    expect(storage.deleted, isEmpty);
  });

  testWidgets('picking twice before saving keeps only what the row names',
      (tester) async {
    const secondPick = 'https://example.test/storage/v1/object/public/'
        'product-images/u1/p1/3000.jpg';

    await pumpForm(tester);

    reportPickedImage(tester, newImage);
    await tester.pumpAndSettle();
    reportPickedImage(tester, secondPick);
    await tester.pumpAndSettle();

    await save(tester);

    expect(repository.updated?.imageUrl, secondPick);
    expect(storage.deleted, unorderedEquals([oldImage, newImage]));
  });
}
