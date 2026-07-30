import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/services/image_storage/image_storage_service.dart';
import 'package:kasbon_pos/core/services/image_storage/supabase_image_storage_service.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/product_grid_item.dart'
    as pos;
import 'package:kasbon_pos/features/products/presentation/widgets/product_grid_item.dart'
    as products;
import 'package:kasbon_pos/features/products/presentation/widgets/product_image.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

/// Stands in for the bucket: a reference becomes a URL under whatever host this
/// environment happens to have.
///
/// Normalises through the real [SupabaseImageStorageService.objectPathFrom]
/// rather than concatenating, because that is the contract - `publicUrlFor`
/// takes a path or a pre-migration URL - and a fake that skips it tests a
/// service the app does not have.
class _HostedImageStorage implements ImageStorageService {
  static const host = 'https://hosted.test';

  @override
  String publicUrlFor(String reference) {
    final objectPath = SupabaseImageStorageService.objectPathFrom(reference);
    if (objectPath == null) return reference;
    return '$host/storage/v1/object/public/'
        '${SupabaseImageStorageService.bucketName}/$objectPath';
  }

  @override
  Future<void> deleteImage(String imagePath) async {}

  @override
  Future<bool> imageExists(String imagePath) async => true;

  @override
  Future<String> saveImage(PickedImage image, String productId) async =>
      throw UnimplementedError();
}

/// A row holds an object path, so no render site may hand `image_url` straight
/// to `Image.network`.
///
/// The URL used to be in the row, which meant the host that wrote it was too: a
/// photo uploaded from Chrome against `127.0.0.1` could not load in the Android
/// emulator, on a real device over the LAN, or from production. These pin the
/// resolution to the one place that knows the host - and the fallback that used
/// to swallow a path silently, by treating anything non-`http` as a file on
/// this device.
void main() {
  const objectPath = 'u1/p1/1690000000000.jpg';
  const expectedUrl = '${_HostedImageStorage.host}'
      '/storage/v1/object/public/product-images/$objectPath';
  const devicePath = '/data/user/0/id.kasbon.app/app_flutter/p1.jpg';

  setUp(() {
    getIt.registerSingleton<ImageStorageService>(_HostedImageStorage());
  });

  tearDown(() => getIt.reset());

  /// The URL every `Image` in the tree is loading.
  List<String> loadedUrls(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .whereType<NetworkImage>()
      .map((provider) => provider.url)
      .toList();

  group('ProductImage', () {
    testWidgets('resolves an object path against the current host',
        (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        const ProductImage(imagePath: objectPath),
      );

      expect(loadedUrls(tester), [expectedUrl]);
    });

    testWidgets('re-points a full URL from before the migration',
        (tester) async {
      // Written against a local stack, read here from somewhere else. The
      // object path inside it is still right, so the row renders without having
      // been rewritten.
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        const ProductImage(
          imagePath: 'http://127.0.0.1:54321/storage/v1/object/public/'
              'product-images/$objectPath',
        ),
      );

      expect(loadedUrls(tester), [expectedUrl]);
    });

    testWidgets('leaves a legacy device path off the network', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        const ProductImage(imagePath: devicePath),
      );

      expect(loadedUrls(tester), isEmpty);
    });
  });

  testWidgets('the products grid resolves the same way', (tester) async {
    // Sized the way the grid sizes it - the card asserts on a height it was not
    // given, which has nothing to do with what is being tested here.
    await pumpAtWidth(
      tester,
      ResponsiveWidths.large,
      Builder(
        builder: (context) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: products.ProductGridItem.extentFor(context, 200),
            child: products.ProductGridItem(
              product: MockData.createProduct(imageUrl: objectPath),
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(loadedUrls(tester), [expectedUrl]);
  });

  testWidgets('the POS grid resolves the same way', (tester) async {
    await pumpAtWidth(
      tester,
      ResponsiveWidths.compact,
      SizedBox(
        width: 200,
        height: 260,
        child: pos.ProductGridItem(
          product: MockData.createProduct(imageUrl: objectPath),
          onTap: () {},
        ),
      ),
    );

    expect(loadedUrls(tester), [expectedUrl]);
  });
}
