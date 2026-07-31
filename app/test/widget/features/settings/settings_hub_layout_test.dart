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

      // The hub is a reading-width column at every tier, so nothing here has
      // any business overflowing even on a 1600dp window.
      expect(tester.takeException(), isNull);
    });
  }

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

    // Five groups holding seven rows. Before the restyle every row carried its
    // own outlined card, so the count of cards tracked the count of rows.
    expect(find.byType(SettingsTile), findsNWidgets(7));
    expect(find.byType(Divider), findsNWidgets(2));
  });
}
