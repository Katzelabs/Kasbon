import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';
import 'package:kasbon_pos/features/receipt/domain/repositories/shop_settings_repository.dart';
import 'package:kasbon_pos/features/receipt/domain/usecases/get_shop_settings.dart';
import 'package:kasbon_pos/features/settings/domain/usecases/update_shop_settings.dart';
import 'package:kasbon_pos/features/settings/presentation/screens/settings_screen.dart';
import 'package:kasbon_pos/features/settings/presentation/widgets/settings_tile.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/responsive_helpers.dart';

class _FakeShopSettingsRepository implements ShopSettingsRepository {
  _FakeShopSettingsRepository(this.stored, {this.fail = false});

  ShopSettings stored;
  final bool fail;

  @override
  Future<Either<Failure, ShopSettings>> getShopSettings() async {
    if (fail) return const Left(NetworkFailure(message: 'Tidak ada koneksi'));
    return Right(stored);
  }

  @override
  Future<Either<Failure, void>> updateShopSettings(
      ShopSettings settings) async {
    stored = settings;
    return const Right(null);
  }
}

void main() {
  ShopSettings settings({
    String? address = 'Jl. Merdeka 10',
    String? phone = '081234567890',
  }) {
    return ShopSettings(
      id: 'test',
      name: 'Warung Bu Siti',
      address: address,
      phone: phone,
      lowStockThreshold: 7,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  void register(ShopSettings initial, {bool fail = false}) {
    final repository = _FakeShopSettingsRepository(initial, fail: fail);
    getIt.registerLazySingleton<GetShopSettings>(
      () => GetShopSettings(repository),
    );
    getIt.registerLazySingleton<UpdateShopSettings>(
      () => UpdateShopSettings(repository),
    );
  }

  tearDown(() => getIt.reset());

  for (final width in ResponsiveWidths.all) {
    testWidgets('lays out every group at ${ResponsiveWidths.label(width)}',
        (tester) async {
      register(settings());

      await pumpScreenAtWidth(tester, width, const SettingsScreen());

      for (final heading in ['TOKO', 'APLIKASI', 'DATA', 'TENTANG', 'AKUN']) {
        expect(find.text(heading), findsOneWidget);
      }

      // Rows stay at reading width whatever the window does, so nothing here
      // has any business overflowing even on a 1600dp one.
      expect(tester.takeException(), isNull);
    });
  }

  /// Top-left corner of the group whose heading is [heading].
  Offset groupAt(WidgetTester tester, String heading) =>
      tester.getTopLeft(find.text(heading));

  for (final width in [ResponsiveWidths.compact, ResponsiveWidths.medium]) {
    testWidgets(
        'stacks the groups in one column at '
        '${ResponsiveWidths.label(width)}', (tester) async {
      register(settings());

      await pumpScreenAtWidth(tester, width, const SettingsScreen());

      // An iPad in portrait is 834dp - `medium` - and halving that gives two
      // columns too narrow to hold a row's subtitle. It stays a single column.
      final toko = groupAt(tester, 'TOKO');
      final tentang = groupAt(tester, 'TENTANG');

      expect(tentang.dx, toko.dx);
      expect(tentang.dy, greaterThan(toko.dy));
    });
  }

  for (final width in [ResponsiveWidths.expanded, ResponsiveWidths.large]) {
    testWidgets(
        'splits the groups into two columns at '
        '${ResponsiveWidths.label(width)}', (tester) async {
      register(settings());

      await pumpScreenAtWidth(tester, width, const SettingsScreen());

      // What the owner configures on the left, what the app is and who is
      // signed in on the right - the two heading the columns line up level.
      final toko = groupAt(tester, 'TOKO');
      final tentang = groupAt(tester, 'TENTANG');

      expect(tentang.dx, greaterThan(toko.dx));
      expect(tentang.dy, toko.dy);

      // AKUN follows TENTANG down the trailing column rather than starting a
      // third one, and DATA closes the leading column.
      expect(groupAt(tester, 'AKUN').dx, tentang.dx);
      expect(groupAt(tester, 'DATA').dx, toko.dx);
    });
  }

  testWidgets('the account header spans both columns', (tester) async {
    register(settings());

    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.large,
      const SettingsScreen(),
    );

    // It is the page's subject, not one of the groups: it sits above the split
    // and reaches across both columns.
    final header = tester.getRect(
      find
          .ancestor(
            of: find.byType(ModernAvatar),
            matching: find.byType(ModernCard),
          )
          .first,
    );
    final tentang = groupAt(tester, 'TENTANG');

    expect(header.bottom, lessThan(tentang.dy));
    expect(header.left, lessThan(tentang.dx));
    expect(header.right, greaterThan(tentang.dx));
  });

  testWidgets('shows the shop name and threshold once loaded', (tester) async {
    register(settings());

    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const SettingsScreen(),
    );

    expect(find.text('Warung Bu Siti'), findsOneWidget);
    expect(find.text('Batas stok rendah: 7'), findsOneWidget);
  });

  testWidgets('names what the shop profile is still missing', (tester) async {
    register(settings(phone: null));

    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const SettingsScreen(),
    );

    expect(
      find.textContaining('Lengkapi telepon'),
      findsOneWidget,
      reason: 'the row should prompt for the fields a receipt will miss',
    );
  });

  testWidgets('a failed load costs two subtitles, not the whole screen',
      (tester) async {
    register(settings(), fail: true);

    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const SettingsScreen(),
    );

    // The screen used to hand the entire body to a ModernErrorState, so a
    // dropped connection took Backup, Keluar and everything else with it.
    expect(find.text('Gagal memuat data toko'), findsOneWidget);
    expect(find.text('Profil Toko'), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
  });

  testWidgets('groups its rows into one card per section', (tester) async {
    register(settings());

    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const SettingsScreen(),
    );

    // Five groups holding nine rows. Before the restyle every row carried its
    // own outlined card, so the count of cards tracked the count of rows.
    expect(find.byType(SettingsTile), findsNWidgets(9));
    expect(find.byType(Divider), findsNWidgets(4));
  });

  testWidgets('names the privacy policy on the hub itself', (tester) async {
    register(settings());

    await pumpScreenAtWidth(
      tester,
      ResponsiveWidths.compact,
      const SettingsScreen(),
    );

    // Both stores look for the policy from Settings, and it used to be
    // reachable only by opening "Tentang Aplikasi" first.
    expect(find.text('Kebijakan Privasi'), findsOneWidget);
  });
}
