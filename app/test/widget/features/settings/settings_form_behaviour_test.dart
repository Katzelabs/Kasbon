import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/di/injection.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';
import 'package:kasbon_pos/features/receipt/domain/repositories/shop_settings_repository.dart';
import 'package:kasbon_pos/features/receipt/domain/usecases/get_shop_settings.dart';
import 'package:kasbon_pos/features/settings/domain/usecases/update_shop_settings.dart';
import 'package:kasbon_pos/features/settings/presentation/providers/settings_provider.dart';
import 'package:kasbon_pos/features/settings/presentation/screens/app_settings_screen.dart';
import 'package:kasbon_pos/features/settings/presentation/screens/shop_profile_screen.dart';

import '../../../helpers/responsive_helpers.dart';

/// In-memory stand-in for the Supabase-backed repository.
class _FakeShopSettingsRepository implements ShopSettingsRepository {
  _FakeShopSettingsRepository(this.stored, {this.readDelay = Duration.zero});

  ShopSettings stored;
  int writes = 0;

  /// Simulated round-trip time.
  ///
  /// Zero for most tests, where the response may as well be instant. The
  /// blank-frame test needs a window it can actually pump inside of - with no
  /// delay the load resolves in the same microtask drain as the first frame,
  /// and the very bug being guarded against becomes unobservable.
  final Duration readDelay;

  @override
  Future<Either<Failure, ShopSettings>> getShopSettings() async {
    if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
    return Right(stored);
  }

  @override
  Future<Either<Failure, void>> updateShopSettings(
      ShopSettings settings) async {
    writes++;
    stored = settings;
    return const Right(null);
  }
}

ShopSettings _settings({
  String name = 'Warung Bu Siti',
  String? address = 'Jl. Merdeka 10',
  String? phone = '081234567890',
  int lowStockThreshold = 5,
}) {
  return ShopSettings(
    id: 'test',
    name: name,
    address: address,
    phone: phone,
    lowStockThreshold: lowStockThreshold,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  late _FakeShopSettingsRepository repository;

  void register(ShopSettings initial, {Duration readDelay = Duration.zero}) {
    repository = _FakeShopSettingsRepository(initial, readDelay: readDelay);
    getIt.registerLazySingleton<GetShopSettings>(
      () => GetShopSettings(repository),
    );
    getIt.registerLazySingleton<UpdateShopSettings>(
      () => UpdateShopSettings(repository),
    );
  }

  tearDown(() => getIt.reset());

  group('shop profile form', () {
    testWidgets('renders the loaded values without a blank first frame',
        (tester) async {
      register(_settings(), readDelay: const Duration(milliseconds: 50));

      // Deliberately not settled: this asserts on the frames *between* mount
      // and the response landing. The screen used to render its fields empty
      // there, because loading was kicked off from a post-frame callback while
      // `isLoading` still defaulted to false - so the sequence a user saw was
      // blank form, spinner, filled form.
      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const ShopProfileScreen(),
        settle: false,
      );
      await tester.pump();

      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'no field should exist until there is a value to put in it',
      );
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Warung Bu Siti'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Jl. Merdeka 10'), findsOneWidget);
    });

    testWidgets('Simpan stays disabled until something changes',
        (tester) async {
      register(_settings());

      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const ShopProfileScreen(),
      );

      expect(find.text('Tersimpan'), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Warung Bu Sity');
      await tester.pumpAndSettle();

      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Tersimpan'), findsNothing);
    });

    testWidgets('typing a value back to the original disarms Simpan again',
        (tester) async {
      register(_settings());

      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const ShopProfileScreen(),
      );

      await tester.enterText(find.byType(TextField).first, 'Berubah');
      await tester.pumpAndSettle();
      expect(find.text('Simpan'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Warung Bu Siti');
      await tester.pumpAndSettle();

      expect(
        find.text('Tersimpan'),
        findsOneWidget,
        reason: 'dirtiness is a comparison against the baseline, not a latch',
      );
    });
  });

  group('app settings form', () {
    testWidgets('the stepper drives both the value and the example line',
        (tester) async {
      register(_settings(lowStockThreshold: 5));

      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const AppSettingsScreen(),
      );

      expect(find.textContaining('stok 5 atau kurang'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.textContaining('stok 6 atau kurang'), findsOneWidget);
      expect(find.text('Simpan Pengaturan'), findsOneWidget);
    });

    testWidgets('a preset chip sets the threshold in one tap', (tester) async {
      register(_settings(lowStockThreshold: 5));

      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.compact,
        const AppSettingsScreen(),
      );

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      expect(find.textContaining('stok 10 atau kurang'), findsOneWidget);
    });
  });

  group('saving', () {
    /// Reads the notifier without pumping a screen.
    ProviderContainer containerFor() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('clearing an optional field persists as NULL', () async {
      register(_settings(phone: '081234567890'));

      final container = containerFor();
      final notifier = container.read(settingsFormProvider.notifier);

      // Let the constructor's load land.
      await container.read(settingsFormProvider.notifier).loadSettings();

      notifier.setPhone('');
      final saved = await notifier.saveShopProfile();

      expect(saved, isTrue);
      expect(
        repository.stored.phone,
        isNull,
        reason: 'ShopSettings.copyWith coalesces with ??, so a null there '
            'meant "keep the old phone" and the field could never be cleared',
      );
    });

    test('a successful save resets the baseline, so the form reads clean',
        () async {
      register(_settings());

      final container = containerFor();
      final notifier = container.read(settingsFormProvider.notifier);
      await notifier.loadSettings();

      notifier.setName('Warung Bu Sinta');
      expect(container.read(settingsFormProvider).isShopProfileDirty, isTrue);

      await notifier.saveShopProfile();

      expect(container.read(settingsFormProvider).isShopProfileDirty, isFalse);
      expect(repository.stored.name, 'Warung Bu Sinta');
    });

    test('editing the receipt does not make the shop profile dirty', () async {
      register(_settings());

      final container = containerFor();
      final notifier = container.read(settingsFormProvider.notifier);
      await notifier.loadSettings();

      notifier.setReceiptFooter('Sampai jumpa!');
      final state = container.read(settingsFormProvider);

      expect(state.isReceiptDirty, isTrue);
      expect(
        state.isShopProfileDirty,
        isFalse,
        reason: 'the three forms share one provider, so an undivided dirty '
            'flag would arm Simpan and the discard prompt on all of them',
      );
    });

    test('whitespace-only edits do not count as changes', () async {
      register(_settings(name: 'Warung Bu Siti'));

      final container = containerFor();
      final notifier = container.read(settingsFormProvider.notifier);
      await notifier.loadSettings();

      notifier.setName('  Warung Bu Siti  ');

      expect(container.read(settingsFormProvider).isShopProfileDirty, isFalse);
    });
  });
}
