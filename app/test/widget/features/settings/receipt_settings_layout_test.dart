import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';
import 'package:kasbon_pos/features/receipt/domain/repositories/shop_settings_repository.dart';
import 'package:kasbon_pos/features/receipt/domain/usecases/get_shop_settings.dart';
import 'package:kasbon_pos/features/receipt/presentation/widgets/receipt_preview_widget.dart';
import 'package:kasbon_pos/features/settings/domain/usecases/update_shop_settings.dart';
import 'package:kasbon_pos/features/settings/presentation/screens/receipt_settings_screen.dart';

import '../../../helpers/responsive_helpers.dart';

/// Stands in for Supabase, which a widget test has no connection to.
///
/// The screen resolves `GetShopSettings` out of `getIt`, so without a
/// registration the load fails and the screen renders its error state - which
/// is correct behaviour, and exactly what this file needs to get past to be
/// able to test a layout. It previously got away with registering nothing
/// because the screen ignored a failed load and drew the form anyway, over
/// values it did not have.
class _FakeShopSettingsRepository implements ShopSettingsRepository {
  ShopSettings stored = ShopSettings(
    id: 'test',
    name: 'Warung Bu Siti',
    address: 'Jl. Merdeka 10',
    phone: '081234567890',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Future<Either<Failure, ShopSettings>> getShopSettings() async =>
      Right(stored);

  @override
  Future<Either<Failure, void>> updateShopSettings(ShopSettings settings) async {
    stored = settings;
    return const Right(null);
  }
}

/// The highest-value wide layout in Settings: a live receipt preview docked
/// beside the form that edits it.
///
/// The preview is also no longer an approximation. It used to be a hand-built
/// card - centred shop name, two sample rows, a total - which is not what the
/// printer produces, so a header that looked fine while editing could still
/// wrap at 42 characters on paper. It now runs the form state through the same
/// `ReceiptGenerator` and `ReceiptPreviewWidget` the real receipt screen uses.
void main() {
  // The preview runs the real generator, which formats the sample sale's date
  // in `id_ID`. `main.dart` initialises this before runApp; a test has to too.
  setUpAll(() => initializeDateFormatting('id_ID', null));

  setUp(() {
    final repository = _FakeShopSettingsRepository();
    getIt.registerLazySingleton<GetShopSettings>(
      () => GetShopSettings(repository),
    );
    getIt.registerLazySingleton<UpdateShopSettings>(
      () => UpdateShopSettings(repository),
    );
  });

  tearDown(() => getIt.reset());

  Finder formCard() => find.text('Kustomisasi Struk');
  Finder preview() => find.byType(ReceiptPreviewWidget);

  for (final width in ResponsiveWidths.all) {
    testWidgets(
      'shows the form and a real receipt preview at ${ResponsiveWidths.label(width)}',
      (tester) async {
        await pumpScreenAtWidth(
          tester,
          width,
          const ReceiptSettingsScreen(),
        );

        expect(formCard(), findsOneWidget);
        expect(find.text('Pratinjau Struk'), findsOneWidget);
        expect(preview(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('stacks the preview above the form on a phone', (tester) async {
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const ReceiptSettingsScreen(),
    );

    expect(
      tester.getTopLeft(preview()).dy,
      lessThan(tester.getTopLeft(formCard()).dy),
      reason: 'the preview should lead on a narrow window',
    );
  });

  for (final width in [ResponsiveWidths.expanded, ResponsiveWidths.large]) {
    testWidgets(
      'docks the preview beside the form at ${ResponsiveWidths.label(width)}',
      (tester) async {
        await pumpScreenAtWidth(
          tester,
          width,
          const ReceiptSettingsScreen(),
        );

        final formRight =
            tester.getBottomRight(find.byType(TextField).first).dx;
        final previewLeft = tester.getTopLeft(preview()).dx;

        expect(
          previewLeft,
          greaterThan(formRight),
          reason: 'the preview should start to the right of the form column',
        );
      },
    );
  }

  testWidgets('the preview follows what is typed into the header',
      (tester) async {
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.expanded,
      const ReceiptSettingsScreen(),
    );

    String previewText() =>
        tester.widget<ReceiptPreviewWidget>(preview()).receiptText;

    expect(previewText(), isNot(contains('PROMO AKHIR TAHUN')));

    await tester.enterText(find.byType(TextField).first, 'PROMO AKHIR TAHUN');
    await tester.pumpAndSettle();

    expect(previewText(), contains('PROMO AKHIR TAHUN'));
  });

  testWidgets('the preview is the real 42-column receipt, not a mock-up',
      (tester) async {
    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.expanded,
      const ReceiptSettingsScreen(),
    );

    final text = tester.widget<ReceiptPreviewWidget>(preview()).receiptText;

    // The things that make it a receipt rather than a card: the rules the
    // generator draws, the transaction line, and the change calculation. None
    // of these existed in the hand-built preview, and all of them are what the
    // printer will actually emit.
    expect(text, contains('=' * 42));
    expect(text, contains('-' * 42));
    expect(text, contains('TOTAL'));
    expect(text, contains('Kembalian'));
    expect(text, contains('Produk A'));
  });
}
