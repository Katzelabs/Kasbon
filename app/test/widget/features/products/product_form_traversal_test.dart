import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/services/image_storage/image_storage_service.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/presentation/providers/categories_provider.dart';
import 'package:kasbon_pos/features/products/presentation/screens/product_form_screen.dart';

import '../../../helpers/responsive_helpers.dart';

class _NoopImageStorage implements ImageStorageService {
  @override
  String publicUrlFor(String reference) => reference;

  @override
  Future<void> deleteImage(String imagePath) async {}

  @override
  Future<bool> imageExists(String imagePath) async => false;

  @override
  Future<String> saveImage(PickedImage image, String productId) async => '';
}

void main() {
  setUp(() {
    if (!getIt.isRegistered<ImageStorageService>()) {
      getIt.registerSingleton<ImageStorageService>(_NoopImageStorage());
    }
  });

  tearDown(() => getIt.reset());

  testWidgets('the two-column form tabs card by card, alternating columns',
      (tester) async {
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.large,
      const ProductFormScreen(),
      providerOverrides: [
        categoriesProvider.overrideWith((ref) async => <Category>[]),
      ],
      settle: false,
    );
    await tester.pump();

    // The cards, and the fields in each:
    //
    //   left column                        right column
    //   --------------------------------   ------------------
    //   Foto (no tab stop)                 Harga Modal, Harga Jual
    //   Nama Produk, Deskripsi, Kategori   Barcode
    //   Stok Awal, Min. Stok, Satuan       Simpan
    //
    // What this guards is that the cards stay whole. Flutter's default reading
    // order sorts focus nodes into horizontal bands, and the bands here depend
    // on how tall each card happens to be - Deskripsi is a multi-line field
    // that grows as it is typed into. So Barcode lands in the middle of the
    // Nama/Deskripsi/Kategori run, and can move while the user is typing.
    final visited = <String>[];

    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final context = FocusManager.instance.primaryFocus?.context;
      final label = context
          ?.findAncestorWidgetOfExactType<TextField>()
          ?.decoration
          ?.labelText;
      if (label != null && !visited.contains(label)) visited.add(label);
    }

    int at(String label) => visited.indexWhere((l) => l.startsWith(label));

    expect(at('Nama Produk'), isNonNegative, reason: 'visited: $visited');
    expect(at('Barcode'), isNonNegative, reason: 'visited: $visited');

    // Barcode is the whole of the right column's second card, so it must come
    // after every field of the left column's second card - not between them.
    expect(
      at('Barcode'),
      greaterThan(at('Kategori')),
      reason: 'the right column interleaved into the left: $visited',
    );
    expect(
      at('Barcode'),
      greaterThan(at('Deskripsi')),
      reason: 'the right column interleaved into the left: $visited',
    );

    // And the row order holds across the pair: prices (row 1) before stock
    // (row 3).
    expect(
      at('Harga Modal'),
      lessThan(at('Stok Awal')),
      reason: 'row order broke: $visited',
    );
  });
}
